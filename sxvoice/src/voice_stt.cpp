#include "sx/voice_stt.hpp"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <mutex>
#include <vector>

#if defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER
#include "whisper.h"
#endif

namespace sx::voice {
namespace {

constexpr const char* kNotBuilt = "voice STT not built";

#if defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER

std::mutex g_mu;
std::string g_grammar;
std::string g_model_path;

std::string default_model_path() {
    if (const char* env = std::getenv("SX_WHISPER_MODEL"); env && env[0]) {
        return env;
    }
#ifdef SX_WHISPER_DEFAULT_MODEL
    return SX_WHISPER_DEFAULT_MODEL;
#else
    return "tools/whisper/ggml-tiny.en.bin";
#endif
}

// Minimal RIFF WAVE reader: PCM 16-bit, mono or first channel only.
bool read_wav_pcm16(const std::string& path, std::vector<int16_t>& out, int& sample_rate,
                    std::string& err) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        err = "failed to open WAV: " + path;
        return false;
    }
    auto read_u32 = [&](uint32_t& v) -> bool {
        char b[4];
        if (!in.read(b, 4)) return false;
        v = uint32_t(uint8_t(b[0])) | (uint32_t(uint8_t(b[1])) << 8) |
            (uint32_t(uint8_t(b[2])) << 16) | (uint32_t(uint8_t(b[3])) << 24);
        return true;
    };
    auto read_u16 = [&](uint16_t& v) -> bool {
        char b[2];
        if (!in.read(b, 2)) return false;
        v = uint16_t(uint8_t(b[0])) | (uint16_t(uint8_t(b[1])) << 8);
        return true;
    };

    char riff[4], wave[4];
    uint32_t riff_size = 0;
    if (!in.read(riff, 4) || std::memcmp(riff, "RIFF", 4) != 0 || !read_u32(riff_size) ||
        !in.read(wave, 4) || std::memcmp(wave, "WAVE", 4) != 0) {
        err = "not a RIFF/WAVE file";
        return false;
    }
    (void)riff_size;

    uint16_t audio_format = 0, num_channels = 0, bits_per_sample = 0;
    uint32_t sample_rate_u = 0;
    std::vector<char> data;
    bool got_fmt = false;

    while (in && !in.eof()) {
        char id[4];
        uint32_t chunk_size = 0;
        if (!in.read(id, 4) || !read_u32(chunk_size)) break;
        if (std::memcmp(id, "fmt ", 4) == 0) {
            if (chunk_size < 16) {
                err = "invalid fmt chunk";
                return false;
            }
            if (!read_u16(audio_format) || !read_u16(num_channels) || !read_u32(sample_rate_u)) {
                err = "truncated fmt chunk";
                return false;
            }
            uint32_t byte_rate = 0;
            uint16_t block_align = 0;
            if (!read_u32(byte_rate) || !read_u16(block_align) || !read_u16(bits_per_sample)) {
                err = "truncated fmt chunk";
                return false;
            }
            (void)byte_rate;
            (void)block_align;
            // Skip any remaining fmt bytes.
            if (chunk_size > 16) in.seekg(chunk_size - 16, std::ios::cur);
            got_fmt = true;
        } else if (std::memcmp(id, "data", 4) == 0) {
            data.resize(chunk_size);
            if (!in.read(data.data(), static_cast<std::streamsize>(chunk_size))) {
                err = "truncated data chunk";
                return false;
            }
            break;
        } else {
            in.seekg(chunk_size, std::ios::cur);
        }
    }

    if (!got_fmt || data.empty()) {
        err = "WAV missing fmt or data";
        return false;
    }
    if (audio_format != 1) {
        err = "WAV must be PCM (format 1)";
        return false;
    }
    if (bits_per_sample != 16) {
        err = "WAV must be 16-bit PCM";
        return false;
    }
    if (num_channels < 1) {
        err = "WAV has no channels";
        return false;
    }

    sample_rate = static_cast<int>(sample_rate_u);
    const size_t frame_bytes = size_t(num_channels) * 2;
    const size_t n_frames = data.size() / frame_bytes;
    out.resize(n_frames);
    for (size_t i = 0; i < n_frames; ++i) {
        const auto* p = reinterpret_cast<const int16_t*>(data.data() + i * frame_bytes);
        out[i] = p[0];  // mono / left
    }
    return true;
}

struct WhisperState {
    whisper_context* ctx = nullptr;
    std::string loaded_model;
};

WhisperState& whisper_state() {
    static WhisperState s;
    return s;
}

bool ensure_ctx(std::string& err) {
    auto& st = whisper_state();
    const std::string path = g_model_path.empty() ? default_model_path() : g_model_path;
    if (st.ctx && st.loaded_model == path) return true;
    if (st.ctx) {
        whisper_free(st.ctx);
        st.ctx = nullptr;
        st.loaded_model.clear();
    }
    whisper_context_params cparams = whisper_context_default_params();
    st.ctx = whisper_init_from_file_with_params(path.c_str(), cparams);
    if (!st.ctx) {
        err = "failed to load whisper model: " + path;
        return false;
    }
    st.loaded_model = path;
    return true;
}

Transcript run_whisper(const std::vector<float>& pcmf32, int sample_rate) {
    Transcript t;
    if (sample_rate != WHISPER_SAMPLE_RATE) {
        // Simple nearest-neighbor resample to 16 kHz (commands are short).
        if (sample_rate <= 0) {
            t.error = "invalid sample rate";
            return t;
        }
    }
    std::vector<float> input = pcmf32;
    if (sample_rate != WHISPER_SAMPLE_RATE) {
        const double ratio = double(WHISPER_SAMPLE_RATE) / double(sample_rate);
        const size_t n_out = size_t(double(pcmf32.size()) * ratio);
        input.resize(n_out);
        for (size_t i = 0; i < n_out; ++i) {
            const size_t src = size_t(double(i) / ratio);
            input[i] = pcmf32[std::min(src, pcmf32.size() - 1)];
        }
    }

    std::lock_guard<std::mutex> lock(g_mu);
    if (!ensure_ctx(t.error)) return t;

    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress = false;
    wparams.print_special = false;
    wparams.print_realtime = false;
    wparams.print_timestamps = false;
    wparams.single_segment = true;
    wparams.no_context = true;
    wparams.language = "en";
    // Grammar GBNF needs whisper's example grammar-parser; stored but not applied yet.
    (void)g_grammar;

    if (whisper_full(whisper_state().ctx, wparams, input.data(), int(input.size())) != 0) {
        t.error = "whisper_full failed";
        return t;
    }

    const int n_seg = whisper_full_n_segments(whisper_state().ctx);
    std::string text;
    float conf_sum = 0.f;
    int conf_n = 0;
    for (int i = 0; i < n_seg; ++i) {
        const char* seg = whisper_full_get_segment_text(whisper_state().ctx, i);
        if (seg) text += seg;
        const int n_tok = whisper_full_n_tokens(whisper_state().ctx, i);
        for (int j = 0; j < n_tok; ++j) {
            conf_sum += whisper_full_get_token_p(whisper_state().ctx, i, j);
            ++conf_n;
        }
    }
    // Trim leading/trailing whitespace.
    while (!text.empty() && (text.front() == ' ' || text.front() == '\n')) text.erase(text.begin());
    while (!text.empty() && (text.back() == ' ' || text.back() == '\n')) text.pop_back();
    t.text = std::move(text);
    t.confidence = conf_n > 0 ? conf_sum / float(conf_n) : 0.f;
    return t;
}

#endif  // SX_VOICE_HAS_WHISPER

}  // namespace

bool stt_available() {
#if defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER
    return true;
#else
    return false;
#endif
}

Transcript transcribe_wav(const std::string& wav_path) {
#if !(defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER)
    (void)wav_path;
    Transcript t;
    t.error = kNotBuilt;
    return t;
#else
    Transcript t;
    std::vector<int16_t> pcm;
    int sr = 0;
    if (!read_wav_pcm16(wav_path, pcm, sr, t.error)) return t;
    return transcribe_pcm16(pcm.data(), pcm.size(), sr);
#endif
}

Transcript transcribe_pcm16(const int16_t* samples, size_t n, int sample_rate) {
#if !(defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER)
    (void)samples;
    (void)n;
    (void)sample_rate;
    Transcript t;
    t.error = kNotBuilt;
    return t;
#else
    Transcript t;
    if (!samples && n > 0) {
        t.error = "null samples";
        return t;
    }
    std::vector<float> pcmf32(n);
    for (size_t i = 0; i < n; ++i) {
        pcmf32[i] = float(samples[i]) / 32768.f;
    }
    return run_whisper(pcmf32, sample_rate);
#endif
}

bool set_grammar(const std::string& gbnf_path_or_text) {
#if !(defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER)
    (void)gbnf_path_or_text;
    return false;
#else
    // Grammar sampling requires whisper.cpp examples/grammar-parser (not in libwhisper).
    // Store text for a future apply path; report unsupported for now.
    std::lock_guard<std::mutex> lock(g_mu);
    std::ifstream in(gbnf_path_or_text);
    if (in) {
        g_grammar.assign(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
    } else {
        g_grammar = gbnf_path_or_text;
    }
    (void)g_grammar;
    return false;  // no-op until grammar-parser is wired
#endif
}

bool set_model(const std::string& model_path) {
#if !(defined(SX_VOICE_HAS_WHISPER) && SX_VOICE_HAS_WHISPER)
    (void)model_path;
    return false;
#else
    std::lock_guard<std::mutex> lock(g_mu);
    g_model_path = model_path;
    auto& st = whisper_state();
    if (st.ctx) {
        whisper_free(st.ctx);
        st.ctx = nullptr;
        st.loaded_model.clear();
    }
    return !g_model_path.empty();
#endif
}

}  // namespace sx::voice
