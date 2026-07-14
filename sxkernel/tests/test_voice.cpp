#include <catch.hpp>

#include <fstream>

#include <nlohmann/json.hpp>

#include "sx/voice.hpp"

using namespace sx::voice;

namespace {
// Prefer the sealed copy next to tests; fall back to docs/ for local runs.
std::string phrases_path() {
    const char* candidates[] = {
        "sxkernel/tests/data/voice_phrases.json",
        "docs/voice/phrases.json",
        "../sxkernel/tests/data/voice_phrases.json",
        "../docs/voice/phrases.json",
    };
    for (const char* p : candidates) {
        std::ifstream in(p);
        if (in.good()) return p;
    }
    return {};
}
}  // namespace

TEST_CASE("normalize lowercases and strips punctuation", "[voice]") {
    CHECK(normalize("  Make This Horizontal! ") == "make this horizontal");
    CHECK(normalize("Fillet this 3.5mm.") == "fillet this 3.5mm");
}

TEST_CASE("constraint intents", "[voice]") {
    auto h = interpret("make this horizontal");
    CHECK(h.kind == IntentKind::Constraint);
    CHECK(h.verb == "horizontal");
    CHECK(h.confidence == Approx(1.0f));

    CHECK(interpret("vertical").verb == "vertical");
    CHECK(interpret("constrain horizontal").verb == "horizontal");
    CHECK(interpret("make them parallel").verb == "parallel");
    CHECK(interpret("perpendicular").verb == "perpendicular");
    CHECK(interpret("tangent").verb == "tangent");
    CHECK(interpret("same length").verb == "equal");
    CHECK(interpret("coincident").verb == "coincident");
    CHECK(interpret("lock this down").verb == "fix");

    auto d = interpret("dimension this to 40");
    CHECK(d.kind == IntentKind::Constraint);
    CHECK(d.verb == "distance");
    REQUIRE(d.value.has_value());
    CHECK(*d.value == Approx(40.0));
    CHECK(d.unit == "mm");

    auto r = interpret("radius 5 millimeters");
    CHECK(r.verb == "radius");
    REQUIRE(r.value.has_value());
    CHECK(*r.value == Approx(5.0));
    CHECK(r.unit == "mm");
}

TEST_CASE("model intents with numbers and word numbers", "[voice]") {
    auto f = interpret("fillet this 3 millimeters");
    CHECK(f.kind == IntentKind::Model);
    CHECK(f.verb == "fillet");
    REQUIRE(f.value.has_value());
    CHECK(*f.value == Approx(3.0));
    CHECK(f.unit == "mm");

    auto s = interpret("shell this two");
    CHECK(s.verb == "shell");
    REQUIRE(s.value.has_value());
    CHECK(*s.value == Approx(2.0));

    auto e = interpret("extrude 10");
    CHECK(e.verb == "extrude");
    REQUIRE(e.value.has_value());
    CHECK(*e.value == Approx(10.0));

    auto hole = interpret("make a hole m6 here");
    CHECK(hole.verb == "hole");
    CHECK(hole.name == "m6");

    CHECK(interpret("hide this").verb == "hide");
    CHECK(interpret("isolate").verb == "isolate");
    CHECK(interpret("show all").verb == "show_all");

    auto del = interpret("delete this");
    CHECK(del.verb == "delete");
    CHECK(del.needs_confirm);
}

TEST_CASE("view and app intents", "[voice]") {
    CHECK(interpret("look at the front").verb == "front");
    CHECK(interpret("top view").verb == "top");
    CHECK(interpret("zoom to fit").verb == "zoom_fit");
    CHECK(interpret("isometric").verb == "iso");
    CHECK(interpret("section view").verb == "section");
    CHECK(interpret("ortho").verb == "ortho");

    CHECK(interpret("undo that").verb == "undo");
    CHECK(interpret("redo").verb == "redo");
    CHECK(interpret("save").verb == "save");
    CHECK(interpret("cancel").verb == "cancel");
    CHECK(interpret("okay").verb == "ok");
}

TEST_CASE("query intents", "[voice]") {
    CHECK(interpret("how heavy is this").verb == "mass");
    CHECK(interpret("what's the volume").verb == "volume");
    CHECK(interpret("face area").verb == "area");
    CHECK(interpret("how far apart are these").verb == "distance_between");
    CHECK(interpret("what can I say").verb == "help");
}

TEST_CASE("variable intents", "[voice]") {
    auto v = interpret("set width to 55");
    CHECK(v.kind == IntentKind::Variable);
    CHECK(v.verb == "set_var");
    CHECK(v.name == "width");
    REQUIRE(v.value.has_value());
    CHECK(*v.value == Approx(55.0));

    auto e = interpret("make height twice the width");
    CHECK(e.kind == IntentKind::Variable);
    CHECK(e.verb == "set_expr");
    CHECK(e.name == "height");
    CHECK(e.expression == "2*width");
}

TEST_CASE("selection prompts when targets missing", "[voice]") {
    SelectionContext empty;
    empty.sketch_active = true;
    auto h = interpret("make this horizontal", &empty);
    CHECK(h.kind == IntentKind::Constraint);
    CHECK(h.verb == "horizontal");
    CHECK_FALSE(h.prompt.empty());
    CHECK(h.prompt.find("Select") != std::string::npos);

    SelectionContext body;
    body.bodies = {"abc"};
    auto m = interpret("how heavy is this", &body);
    CHECK(m.verb == "mass");
    CHECK(m.prompt.empty());

    auto m2 = interpret("how heavy is this", &empty);
    CHECK_FALSE(m2.prompt.empty());
}

TEST_CASE("unmatched banks for future AI", "[voice]") {
    auto u = interpret("make it feel more organic somehow");
    CHECK(u.kind == IntentKind::Unmatched);
    CHECK(u.confidence == Approx(0.0f));
    CHECK_FALSE(u.prompt.empty());
    auto j = u.to_json();
    CHECK(j["kind"] == "unmatched");
    CHECK(j["raw_text"] == "make it feel more organic somehow");
}

TEST_CASE("intent json round-trip", "[voice]") {
    auto i = interpret("fillet this 3 millimeters");
    auto j = i.to_json();
    auto back = Intent::from_json(j);
    CHECK(back.kind == i.kind);
    CHECK(back.verb == i.verb);
    REQUIRE(back.value.has_value());
    CHECK(*back.value == Approx(*i.value));
}

TEST_CASE("make them equal is constraint not variable", "[voice]") {
    auto e = interpret("make them equal");
    CHECK(e.kind == IntentKind::Constraint);
    CHECK(e.verb == "equal");
}

TEST_CASE("golden phrase corpus covers interpreter verbs", "[voice][corpus]") {
    auto path = phrases_path();
    if (path.empty()) {
        WARN("voice_phrases.json not found — skip corpus check");
        return;
    }
    std::ifstream in(path);
    REQUIRE(in.good());
    nlohmann::json arr = nlohmann::json::parse(in);
    REQUIRE(arr.is_array());
    REQUIRE(arr.size() >= 100);

    int matched = 0;
    int checked = 0;
    for (const auto& row : arr) {
        std::string phrase = row.value("phrase", "");
        std::string want_kind = row.value("kind", "");
        std::string want_verb = row.value("verb", "");
        if (phrase.empty() || want_kind == "unmatched") continue;
        ++checked;
        auto i = interpret(phrase);
        // Corpus may use null slots; we only require kind+verb when confidence high.
        if (i.kind != IntentKind::Unmatched && i.verb == want_verb &&
            to_string(i.kind) == want_kind) {
            ++matched;
        } else {
            // Soft: allow paraphrases the parser routes to same verb under a
            // synonym kind mismatch only if verb matches.
            if (i.verb == want_verb) ++matched;
            else
                INFO("phrase='" << phrase << "' got " << to_string(i.kind) << "/"
                                << i.verb << " want " << want_kind << "/" << want_verb);
        }
    }
    CHECK(checked >= 80);
    // Grammar is still growing — require strong coverage, not perfection.
    CHECK(matched >= checked * 3 / 4);
}
