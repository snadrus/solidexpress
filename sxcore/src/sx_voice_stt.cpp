#include "sx_voice_stt.hpp"

#include <string>

#include <godot_cpp/core/class_db.hpp>

#include "sx/voice_stt.hpp"

using namespace godot;

namespace sx_godot {

static std::string to_std(const String& s) { return s.utf8().get_data(); }

void SxVoiceStt::_bind_methods() {
    ClassDB::bind_method(D_METHOD("available"), &SxVoiceStt::available);
    ClassDB::bind_method(D_METHOD("transcribe_wav", "path"), &SxVoiceStt::transcribe_wav);
    ClassDB::bind_method(D_METHOD("set_grammar", "gbnf_path_or_text"), &SxVoiceStt::set_grammar);
    ClassDB::bind_method(D_METHOD("set_model", "model_path"), &SxVoiceStt::set_model);
}

bool SxVoiceStt::available() const { return sx::voice::stt_available(); }

Dictionary SxVoiceStt::transcribe_wav(const String& path) {
    const sx::voice::Transcript t = sx::voice::transcribe_wav(to_std(path));
    Dictionary d;
    d["text"] = String::utf8(t.text.c_str());
    d["confidence"] = t.confidence;
    d["error"] = String::utf8(t.error.c_str());
    return d;
}

bool SxVoiceStt::set_grammar(const String& gbnf_path_or_text) {
    return sx::voice::set_grammar(to_std(gbnf_path_or_text));
}

bool SxVoiceStt::set_model(const String& model_path) {
    return sx::voice::set_model(to_std(model_path));
}

}  // namespace sx_godot
