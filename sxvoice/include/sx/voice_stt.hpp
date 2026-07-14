#pragma once
// Offline speech-to-text bridge (whisper.cpp when SX_BUILD_VOICE + vendored).
// Pure C++ — no Godot dependency. Intent interpretation lives elsewhere.

#include <cstddef>
#include <cstdint>
#include <string>

namespace sx::voice {

struct Transcript {
    std::string text;
    float confidence = 0.f;  // 0..1 if available, else 0
    std::string error;       // empty on success
};

// True when this build linked whisper.cpp (SX_BUILD_VOICE + thirdparty/whisper.cpp).
bool stt_available();

// Transcribe 16-bit PCM mono WAV bytes, or path to WAV file.
// When built without whisper, returns error="voice STT not built".
Transcript transcribe_wav(const std::string& wav_path);
Transcript transcribe_pcm16(const int16_t* samples, size_t n, int sample_rate);

// Optional: load grammar GBNF path or inline text to constrain decoding.
// Returns false (no-op) if unsupported in this build.
bool set_grammar(const std::string& gbnf_path_or_text);

// Optional: set ggml model path (default: tools/whisper/ggml-tiny.en.bin or
// env SX_WHISPER_MODEL). No-op / false when whisper is not linked.
bool set_model(const std::string& model_path);

}  // namespace sx::voice
