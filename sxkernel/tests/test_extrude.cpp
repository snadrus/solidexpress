#include <catch.hpp>
#include <cmath>

#include "sx/commands_sketch.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"

using namespace sx;

static std::shared_ptr<Sketch> rect_sketch(double w, double h) {
    auto sk = std::make_shared<Sketch>("Rect");
    sk->add_line(0, 0, w, 0);
    sk->add_line(w, 0, w, h);
    sk->add_line(w, h, 0, h);
    sk->add_line(0, h, 0, 0);
    return sk;
}

TEST_CASE("extrude rectangle produces a box solid", "[extrude]") {
    Document doc;
    CommandStack stack;
    auto sk = rect_sketch(40, 30);

    auto cmd = std::make_unique<ExtrudeCommand>(sk, 20.0);
    ExtrudeCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    const Body* b = doc.body(raw->created_body());
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::volume(b->shape) == Approx(40.0 * 30.0 * 20.0).epsilon(1e-6));
    REQUIRE(shape::count(b->shape).faces == 6);

    stack.undo(doc);
    REQUIRE(doc.body_ids().empty());
    stack.redo(doc);
    REQUIRE(doc.body(raw->created_body()) != nullptr);
}

TEST_CASE("symmetric extrude straddles the sketch plane", "[extrude]") {
    Document doc;
    CommandStack stack;
    auto sk = rect_sketch(10, 10);

    auto cmd = std::make_unique<ExtrudeCommand>(sk, 20.0, /*symmetric=*/true);
    ExtrudeCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    const Body* b = doc.body(raw->created_body());
    REQUIRE(shape::volume(b->shape) == Approx(2000.0).epsilon(1e-6));
    auto com = shape::center_of_mass(b->shape);
    REQUIRE(com[2] == Approx(0.0).margin(1e-9));  // centered on the plane
}

TEST_CASE("extrude circle produces a cylinder", "[extrude]") {
    Document doc;
    CommandStack stack;
    auto sk = std::make_shared<Sketch>("Disk");
    sk->add_circle(0, 0, 5);

    auto cmd = std::make_unique<ExtrudeCommand>(sk, 10.0);
    ExtrudeCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    const Body* b = doc.body(raw->created_body());
    REQUIRE(shape::volume(b->shape) == Approx(M_PI * 25 * 10).epsilon(1e-6));
}

TEST_CASE("solve then extrude: constrained sketch drives geometry", "[extrude][solver]") {
    // Sloppy rectangle, constrained to 40x30, then extruded 10.
    auto sk = std::make_shared<Sketch>("Solved");
    auto bo = sk->add_line(0, 0, 38, 2);
    auto ri = sk->add_line(38, 2, 42, 28);
    auto to = sk->add_line(42, 28, 1, 30);
    auto le = sk->add_line(1, 30, 0, 0);
    sk->add_constraint(ConstraintType::Coincident, {{bo, PointRole::End}, {ri, PointRole::Start}});
    sk->add_constraint(ConstraintType::Coincident, {{ri, PointRole::End}, {to, PointRole::Start}});
    sk->add_constraint(ConstraintType::Coincident, {{to, PointRole::End}, {le, PointRole::Start}});
    sk->add_constraint(ConstraintType::Coincident, {{le, PointRole::End}, {bo, PointRole::Start}});
    sk->add_constraint(ConstraintType::Horizontal, {{bo, PointRole::Self}});
    sk->add_constraint(ConstraintType::Horizontal, {{to, PointRole::Self}});
    sk->add_constraint(ConstraintType::Vertical, {{ri, PointRole::Self}});
    sk->add_constraint(ConstraintType::Vertical, {{le, PointRole::Self}});
    sk->add_constraint(ConstraintType::Distance, {{bo, PointRole::Start}, {bo, PointRole::End}}, 40.0);
    sk->add_constraint(ConstraintType::Distance, {{ri, PointRole::Start}, {ri, PointRole::End}}, 30.0);

    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(*sk).ok());

    Document doc;
    CommandStack stack;
    auto cmd = std::make_unique<ExtrudeCommand>(sk, 10.0);
    ExtrudeCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));
    REQUIRE(shape::volume(doc.body(raw->created_body())->shape) ==
            Approx(40.0 * 30.0 * 10.0).epsilon(1e-6));
}

TEST_CASE("revolve half-disk produces a sphere", "[extrude][revolve]") {
    // Profile: semicircle of radius 10 (arc + closing diameter line), revolved
    // 360 deg around the Y axis in sketch space.
    auto sk = std::make_shared<Sketch>("Semi");
    sk->add_arc(0, 0, 10, -M_PI / 2.0, M_PI / 2.0);  // right half arc
    sk->add_line(0, 10, 0, -10);                     // diameter along Y

    Document doc;
    CommandStack stack;
    auto cmd = std::make_unique<RevolveCommand>(
        sk, std::array<double, 2>{0, 0}, std::array<double, 2>{0, 1}, 2.0 * M_PI);
    RevolveCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    const Body* b = doc.body(raw->created_body());
    REQUIRE(b != nullptr);
    REQUIRE(shape::volume(b->shape) == Approx(4.0 / 3.0 * M_PI * 1000).epsilon(1e-4));
}

TEST_CASE("extrude open profile throws", "[extrude]") {
    auto sk = std::make_shared<Sketch>("Open");
    sk->add_line(0, 0, 10, 0);
    Document doc;
    auto cmd = std::make_unique<ExtrudeCommand>(sk, 10.0);
    REQUIRE_THROWS(cmd->execute(doc));
}
