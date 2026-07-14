#include <catch.hpp>

#include <cmath>
#include <stdexcept>

#include "sx/commands_boolean.hpp"
#include "sx/document.hpp"
#include "sx/ids.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("boolean fuse overlapping boxes", "[booleans]") {
    Document doc;
    CommandStack stack;

    auto target = doc.add_body(shape::make_box(10, 10, 10), "A");
    shape::Placement p;
    p.origin = {5, 0, 0};
    auto tool = doc.add_body(shape::make_box(10, 10, 10, p), "B");

    stack.push(doc, std::make_unique<BooleanCommand>(target, tool, BooleanOp::Fuse));

    REQUIRE(doc.body(target) != nullptr);
    REQUIRE(doc.body(tool) == nullptr);
    REQUIRE(doc.body_ids().size() == 1);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(1500.0).epsilon(1e-6));

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body(target) != nullptr);
    REQUIRE(doc.body(tool) != nullptr);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(1000.0).epsilon(1e-6));
    REQUIRE(shape::volume(doc.body(tool)->shape) == Approx(1000.0).epsilon(1e-6));

    REQUIRE(stack.redo(doc));
    REQUIRE(doc.body(target) != nullptr);
    REQUIRE(doc.body(tool) == nullptr);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(1500.0).epsilon(1e-6));
}

TEST_CASE("boolean cut drills a hole", "[booleans]") {
    Document doc;
    CommandStack stack;

    auto target = doc.add_body(shape::make_box(10, 10, 10), "Box");
    shape::Placement p;
    p.origin = {5, 5, 0};
    auto tool = doc.add_body(shape::make_cylinder(2, 10, p), "Drill");

    const double expected = 1000.0 - M_PI * 4.0 * 10.0;
    stack.push(doc, std::make_unique<BooleanCommand>(target, tool, BooleanOp::Cut));

    REQUIRE(doc.body(tool) == nullptr);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(expected).epsilon(1e-4));

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body(target) != nullptr);
    REQUIRE(doc.body(tool) != nullptr);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(1000.0).epsilon(1e-6));

    REQUIRE(stack.redo(doc));
    REQUIRE(doc.body(tool) == nullptr);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(expected).epsilon(1e-4));
}

TEST_CASE("boolean common overlapping boxes", "[booleans]") {
    Document doc;
    CommandStack stack;

    auto target = doc.add_body(shape::make_box(10, 10, 10), "A");
    shape::Placement p;
    p.origin = {5, 0, 0};
    auto tool = doc.add_body(shape::make_box(10, 10, 10, p), "B");

    stack.push(doc, std::make_unique<BooleanCommand>(target, tool, BooleanOp::Common));

    REQUIRE(doc.body(tool) == nullptr);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(500.0).epsilon(1e-6));
}

TEST_CASE("boolean keep_tool leaves tool body", "[booleans]") {
    Document doc;
    CommandStack stack;

    auto target = doc.add_body(shape::make_box(10, 10, 10), "A");
    shape::Placement p;
    p.origin = {5, 0, 0};
    auto tool = doc.add_body(shape::make_box(10, 10, 10, p), "B");

    stack.push(doc, std::make_unique<BooleanCommand>(target, tool, BooleanOp::Fuse, true));

    REQUIRE(doc.body(target) != nullptr);
    REQUIRE(doc.body(tool) != nullptr);
    REQUIRE(doc.body_ids().size() == 2);
    REQUIRE(shape::volume(doc.body(target)->shape) == Approx(1500.0).epsilon(1e-6));
    REQUIRE(shape::volume(doc.body(tool)->shape) == Approx(1000.0).epsilon(1e-6));
}

TEST_CASE("boolean on nonexistent id throws", "[booleans]") {
    Document doc;
    EntityId missing;  // null id
    auto tool = doc.add_body(shape::make_box(1, 1, 1), "T");

    BooleanCommand cmd(missing, tool, BooleanOp::Fuse);
    REQUIRE_THROWS_AS(cmd.execute(doc), std::invalid_argument);
}
