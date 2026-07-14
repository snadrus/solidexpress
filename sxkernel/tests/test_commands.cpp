#include <catch.hpp>

#include "sx/commands_basic.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("add primitive command with undo/redo", "[commands]") {
    Document doc;
    CommandStack stack;

    PrimitiveParams p;
    p.type = PrimitiveType::Box;
    p.a = 10;
    p.b = 10;
    p.c = 10;
    auto cmd = std::make_unique<AddPrimitiveCommand>(p);
    AddPrimitiveCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    EntityId body_id = raw->created_body();
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(stack.can_undo());

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body(body_id) == nullptr);
    REQUIRE(doc.body_ids().empty());
    REQUIRE(stack.can_redo());

    REQUIRE(stack.redo(doc));
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);  // same id restored
    REQUIRE(shape::volume(b->shape) == Approx(1000.0));
    // Subshape ids restored identically too.
    REQUIRE(b->subshape_ids.at(EntityKind::Face).size() == 6);
}

TEST_CASE("delete command restores exact ids on undo", "[commands]") {
    Document doc;
    CommandStack stack;

    auto body_id = doc.add_body(shape::make_sphere(2), "S");
    auto face_id = doc.subshape_id(body_id, EntityKind::Face, 1);

    stack.push(doc, std::make_unique<DeleteBodyCommand>(body_id));
    REQUIRE(doc.body(body_id) == nullptr);

    stack.undo(doc);
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(doc.subshape_id(body_id, EntityKind::Face, 1) == face_id);
}

TEST_CASE("translate command moves body and undoes exactly", "[commands]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    auto com0 = shape::center_of_mass(doc.body(body_id)->shape);
    stack.push(doc, std::make_unique<TranslateBodyCommand>(
                        body_id, std::array<double, 3>{5, 0, 0}));
    auto com1 = shape::center_of_mass(doc.body(body_id)->shape);
    REQUIRE(com1[0] - com0[0] == Approx(5.0).epsilon(1e-9));

    // Face ids survive a translate (topology unchanged).
    REQUIRE(doc.body(body_id)->subshape_ids.at(EntityKind::Face).size() == 6);

    stack.undo(doc);
    auto com2 = shape::center_of_mass(doc.body(body_id)->shape);
    REQUIRE(com2[0] == Approx(com0[0]).margin(1e-9));
}

TEST_CASE("push/pull grows and cuts a box", "[commands][pushpull]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    // Find the +Z top face (normal +Z).
    const Body* b = doc.body(body_id);
    EntityId top_face;
    const auto& face_ids = b->subshape_ids.at(EntityKind::Face);
    for (const auto& fid : face_ids) {
        auto desc = shape::describe_face(doc.resolve(fid));
        if (desc.find("normal (0, 0, 1)") != std::string::npos) top_face = fid;
    }
    REQUIRE(!top_face.is_null());

    SECTION("pull adds material") {
        stack.push(doc, std::make_unique<PushPullCommand>(top_face, 5.0));
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1500.0).epsilon(1e-6));
        stack.undo(doc);
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));
        stack.redo(doc);
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1500.0).epsilon(1e-6));
    }

    SECTION("push removes material") {
        stack.push(doc, std::make_unique<PushPullCommand>(top_face, -3.0));
        REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(700.0).epsilon(1e-6));
    }
}
