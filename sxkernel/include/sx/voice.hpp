#pragma once
// Deterministic voice-command interpreter: text → Intent.
// No audio here — STT (whisper/stub) feeds text; this parser is headlessly
// testable and is the "bridge" to either execute an existing command or
// answer a measure query. Unmatched utterances stay available for a future
// AI-first backend via to_json().

#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace sx::voice {

enum class IntentKind {
    Constraint,
    Model,
    View,
    App,
    Variable,
    Query,
    Unmatched,
};

const char* to_string(IntentKind k);
std::optional<IntentKind> kind_from_string(const std::string& s);

// Selection snapshot the UI attaches so the interpreter can decide whether
// an intent is ready to run (enough / right-kind targets). Entity ids are
// opaque strings (UUID) from the Godot side.
struct SelectionContext {
    std::vector<std::string> bodies;
    std::vector<std::string> faces;
    std::vector<std::string> edges;
    // Sketch-mode entity ids currently selected (empty outside sketch).
    std::vector<std::string> sketch_entities;
    bool sketch_active = false;
};

struct Intent {
    IntentKind kind = IntentKind::Unmatched;
    std::string verb;           // e.g. "horizontal", "fillet", "mass"
    std::optional<double> value;
    std::string unit;           // "mm" | "in" | "deg" | ""
    std::string name;           // variable name for set_var
    std::string expression;     // for set_expr
    std::string raw_text;
    float confidence = 0.f;     // 0..1; 1.0 for exact grammar match
    // Friendly next-step when selection is wrong/empty but verb is known.
    std::string prompt;
    // True when the verb is known but should confirm before execute
    // (delete, etc.) or confidence is low.
    bool needs_confirm = false;

    nlohmann::json to_json() const;
    static Intent from_json(const nlohmann::json& j);
};

// Parse free text into an Intent. Selection is optional; when provided,
// Intent::prompt may be filled explaining what's missing.
Intent interpret(const std::string& utterance,
                 const SelectionContext* selection = nullptr);

// Normalize for matching: lowercase, strip punctuation, collapse spaces.
std::string normalize(const std::string& text);

}  // namespace sx::voice
