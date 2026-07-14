#pragma once
// Godot-facing wrapper around sx::voice::interpret.

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace sx_godot {

class SxVoice : public godot::RefCounted {
    GDCLASS(SxVoice, godot::RefCounted)

public:
    SxVoice() = default;
    ~SxVoice() override = default;

    // selection keys (all optional):
    //   bodies, faces, edges, sketch_entities, sketch_active
    godot::Dictionary interpret(const godot::String& utterance,
                                const godot::Dictionary& selection) const;

    godot::String normalize(const godot::String& text) const;

protected:
    static void _bind_methods();
};

}  // namespace sx_godot
