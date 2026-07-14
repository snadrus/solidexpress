#include "sx_voice.hpp"

#include "sx/voice.hpp"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace sx_godot {
namespace {

std::vector<std::string> to_std_array(const Variant& v) {
    std::vector<std::string> out;
    if (v.get_type() == Variant::PACKED_STRING_ARRAY) {
        PackedStringArray psa = v;
        for (int i = 0; i < psa.size(); ++i)
            out.push_back(String(psa[i]).utf8().get_data());
        return out;
    }
    if (v.get_type() != Variant::ARRAY) return out;
    Array a = v;
    for (int i = 0; i < a.size(); ++i)
        out.push_back(String(a[i]).utf8().get_data());
    return out;
}

Dictionary intent_to_dict(const sx::voice::Intent& i) {
    Dictionary d;
    d["kind"] = String(sx::voice::to_string(i.kind));
    d["verb"] = String(i.verb.c_str());
    if (i.value) d["value"] = *i.value;
    else d["value"] = Variant();
    d["unit"] = String(i.unit.c_str());
    d["name"] = String(i.name.c_str());
    d["expression"] = String(i.expression.c_str());
    d["raw_text"] = String(i.raw_text.c_str());
    d["confidence"] = i.confidence;
    d["prompt"] = String(i.prompt.c_str());
    d["needs_confirm"] = i.needs_confirm;
    return d;
}

}  // namespace

Dictionary SxVoice::interpret(const String& utterance, const Dictionary& selection) const {
    sx::voice::SelectionContext ctx;
    if (selection.has("bodies")) ctx.bodies = to_std_array(selection["bodies"]);
    if (selection.has("faces")) ctx.faces = to_std_array(selection["faces"]);
    if (selection.has("edges")) ctx.edges = to_std_array(selection["edges"]);
    if (selection.has("sketch_entities"))
        ctx.sketch_entities = to_std_array(selection["sketch_entities"]);
    if (selection.has("sketch_active")) ctx.sketch_active = bool(selection["sketch_active"]);

    auto intent = sx::voice::interpret(std::string(utterance.utf8().get_data()), &ctx);
    return intent_to_dict(intent);
}

String SxVoice::normalize(const String& text) const {
    return String(sx::voice::normalize(std::string(text.utf8().get_data())).c_str());
}

void SxVoice::_bind_methods() {
    ClassDB::bind_method(D_METHOD("interpret", "utterance", "selection"), &SxVoice::interpret);
    ClassDB::bind_method(D_METHOD("normalize", "text"), &SxVoice::normalize);
}

}  // namespace sx_godot
