#pragma once
// Thin Godot binding for sx::voice STT (whisper.cpp when enabled).

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace sx_godot {

class SxVoiceStt : public godot::RefCounted {
    GDCLASS(SxVoiceStt, godot::RefCounted)

public:
    SxVoiceStt() = default;
    ~SxVoiceStt() override = default;

    bool available() const;
    // {text: String, confidence: float, error: String}
    godot::Dictionary transcribe_wav(const godot::String& path);
    bool set_grammar(const godot::String& gbnf_path_or_text);
    bool set_model(const godot::String& model_path);

protected:
    static void _bind_methods();
};

}  // namespace sx_godot
