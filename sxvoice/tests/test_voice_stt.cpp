#include <catch.hpp>

#include "sx/voice_stt.hpp"

TEST_CASE("stub mode returns documented error when whisper is not linked", "[voice][stt]") {
#if SX_VOICE_HAS_WHISPER
    // Live audio / model tests are skipped until tools/whisper/ggml-tiny.en.bin
    // is present. Enable with -DSX_BUILD_VOICE=ON and vendored whisper.cpp.
    REQUIRE(sx::voice::stt_available());
    auto t = sx::voice::transcribe_wav("/nonexistent/path.wav");
    REQUIRE_FALSE(t.error.empty());
    REQUIRE(t.error != "voice STT not built");
#else
    REQUIRE_FALSE(sx::voice::stt_available());

    auto from_path = sx::voice::transcribe_wav("any.wav");
    REQUIRE(from_path.text.empty());
    REQUIRE(from_path.confidence == 0.f);
    REQUIRE(from_path.error == "voice STT not built");

    int16_t sample = 0;
    auto from_pcm = sx::voice::transcribe_pcm16(&sample, 1, 16000);
    REQUIRE(from_pcm.text.empty());
    REQUIRE(from_pcm.error == "voice STT not built");

    REQUIRE_FALSE(sx::voice::set_grammar("root ::= \"box\""));
    REQUIRE_FALSE(sx::voice::set_model("tools/whisper/ggml-tiny.en.bin"));
#endif
}
