#include <catch.hpp>

#include "sx/commands_hollow.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

namespace {

EntityId find_top_face(Document& doc, const Body& b) {
    EntityId top;
    for (const auto& fid : b.subshape_ids.at(EntityKind::Face)) {
        auto desc = shape::describe_face(doc.resolve(fid));
        if (desc.find("normal (0, 0, 1)") != std::string::npos) top = fid;
    }
    return top;
}

}  // namespace

TEST_CASE("shell removes top face of a box", "[hollow]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(20, 20, 20), "B");

    const Body* b0 = doc.body(body_id);
    REQUIRE(shape::volume(b0->shape) == Approx(8000.0));

    EntityId top = find_top_face(doc, *b0);
    REQUIRE(!top.is_null());

    stack.push(doc, std::make_unique<ShellCommand>(std::vector<EntityId>{top}, 2.0));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    // Open box: outer 20^3 minus open cavity 16x16x18 = 3392
    const double expected = 3392.0;
    REQUIRE(shape::volume(b->shape) == Approx(expected).epsilon(0.01));

    REQUIRE(stack.undo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(8000.0).epsilon(1e-6));

    REQUIRE(stack.redo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(expected).epsilon(0.01));
}

TEST_CASE("offset body grows and shrinks a box", "[hollow]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0));

    SECTION("outward offset by +2") {
        stack.push(doc, std::make_unique<OffsetBodyCommand>(body_id, 2.0));
        const double vol = shape::volume(doc.body(body_id)->shape);
        // Join offset rounds edges/corners; volume is below sharp 14^3=2744.
        REQUIRE(vol > 2400.0);
        REQUIRE(vol < 2744.0 + 1.0);

        REQUIRE(stack.undo(doc));
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));

        REQUIRE(stack.redo(doc));
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol).epsilon(1e-6));
    }

    SECTION("inward offset by -2") {
        stack.push(doc, std::make_unique<OffsetBodyCommand>(body_id, -2.0));
        // Sharp inward offset of a box: 6^3 = 216
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(216.0).epsilon(0.01));

        REQUIRE(stack.undo(doc));
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));

        REQUIRE(stack.redo(doc));
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(216.0).epsilon(0.01));
    }
}

TEST_CASE("shell rejects mixed bodies, non-faces, and oversized thickness", "[hollow]") {
    Document doc;
    auto a = doc.add_body(shape::make_box(20, 20, 20), "A");
    auto b = doc.add_body(shape::make_box(20, 20, 20), "B");

    EntityId face_a = doc.body(a)->subshape_ids.at(EntityKind::Face).front();
    EntityId face_b = doc.body(b)->subshape_ids.at(EntityKind::Face).front();
    EntityId edge_a = doc.body(a)->subshape_ids.at(EntityKind::Edge).front();

    ShellCommand mixed({face_a, face_b}, 2.0);
    REQUIRE_THROWS_AS(mixed.execute(doc), std::invalid_argument);
    REQUIRE(shape::volume(doc.body(a)->shape) == Approx(8000.0).epsilon(1e-6));
    REQUIRE(shape::volume(doc.body(b)->shape) == Approx(8000.0).epsilon(1e-6));

    ShellCommand bad_kind({edge_a}, 2.0);
    REQUIRE_THROWS_AS(bad_kind.execute(doc), std::invalid_argument);
    REQUIRE(shape::volume(doc.body(a)->shape) == Approx(8000.0).epsilon(1e-6));

    EntityId top = find_top_face(doc, *doc.body(a));
    REQUIRE(!top.is_null());
    // Half the box size: OCCT produces an invalid/null result and we throw.
    ShellCommand too_thick({top}, 10.0);
    REQUIRE_THROWS(too_thick.execute(doc));
    REQUIRE(doc.body(a) != nullptr);
    REQUIRE(shape::volume(doc.body(a)->shape) == Approx(8000.0).epsilon(1e-6));
}
