#include <catch.hpp>
#include <cmath>

#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/solver.hpp"

using namespace sx;

TEST_CASE("sketch entities store and expose parameters", "[sketch]") {
    Sketch sk("Test");
    auto line = sk.add_line(0, 0, 10, 0);
    auto circle = sk.add_circle(5, 5, 2);

    const SketchEntity* le = sk.entity(line);
    REQUIRE(le != nullptr);
    REQUIRE(le->type == SketchEntityType::Line);
    auto start = sk.point_pos({line, PointRole::Start});
    auto end = sk.point_pos({line, PointRole::End});
    REQUIRE(start.has_value());
    REQUIRE((*start)[0] == Approx(0.0));
    REQUIRE((*end)[0] == Approx(10.0));

    auto center = sk.point_pos({circle, PointRole::Center});
    REQUIRE((*center)[0] == Approx(5.0));
    REQUIRE((*center)[1] == Approx(5.0));
}

TEST_CASE("planegcs solves a dimensioned rectangle", "[sketch][solver]") {
    // Four lines, roughly rectangular but sloppy; constraints make it an
    // exact 40x30 rectangle anchored via coincident corners.
    Sketch sk("Rect");
    auto bottom = sk.add_line(0, 0, 38, 1);
    auto right = sk.add_line(38, 1, 41, 29);
    auto top = sk.add_line(41, 29, 2, 31);
    auto left = sk.add_line(2, 31, 0, 0);

    sk.add_constraint(ConstraintType::Coincident,
                      {{bottom, PointRole::End}, {right, PointRole::Start}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{right, PointRole::End}, {top, PointRole::Start}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{top, PointRole::End}, {left, PointRole::Start}});
    sk.add_constraint(ConstraintType::Coincident,
                      {{left, PointRole::End}, {bottom, PointRole::Start}});
    sk.add_constraint(ConstraintType::Horizontal, {{bottom, PointRole::Self}});
    sk.add_constraint(ConstraintType::Horizontal, {{top, PointRole::Self}});
    sk.add_constraint(ConstraintType::Vertical, {{right, PointRole::Self}});
    sk.add_constraint(ConstraintType::Vertical, {{left, PointRole::Self}});
    sk.add_constraint(ConstraintType::Distance,
                      {{bottom, PointRole::Start}, {bottom, PointRole::End}}, 40.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{right, PointRole::Start}, {right, PointRole::End}}, 30.0);

    auto solver = make_planegcs_backend();
    SolveResult res = solver->solve(sk);
    REQUIRE(res.ok());

    auto p0 = *sk.point_pos({bottom, PointRole::Start});
    auto p1 = *sk.point_pos({bottom, PointRole::End});
    auto p2 = *sk.point_pos({right, PointRole::End});
    double width = std::hypot(p1[0] - p0[0], p1[1] - p0[1]);
    double height = std::hypot(p2[0] - p1[0], p2[1] - p1[1]);
    REQUIRE(width == Approx(40.0).margin(1e-6));
    REQUIRE(height == Approx(30.0).margin(1e-6));
    // Horizontal means equal y at both ends.
    REQUIRE(p0[1] == Approx(p1[1]).margin(1e-6));
}

TEST_CASE("planegcs solves circle radius constraint", "[sketch][solver]") {
    Sketch sk("Circ");
    auto c = sk.add_circle(10, 10, 7);
    sk.add_constraint(ConstraintType::Radius, {{c, PointRole::Self}}, 12.5);

    auto solver = make_planegcs_backend();
    REQUIRE(solver->solve(sk).ok());
    const SketchEntity* ce = sk.entity(c);
    REQUIRE(sk.param(ce->params[2]) == Approx(12.5).margin(1e-6));
}

TEST_CASE("solver reports failure for conflicting constraints", "[sketch][solver]") {
    Sketch sk("Bad");
    auto l = sk.add_line(0, 0, 10, 0);
    sk.add_constraint(ConstraintType::Distance,
                      {{l, PointRole::Start}, {l, PointRole::End}}, 10.0);
    sk.add_constraint(ConstraintType::Distance,
                      {{l, PointRole::Start}, {l, PointRole::End}}, 20.0);

    auto solver = make_planegcs_backend();
    SolveResult res = solver->solve(sk);
    REQUIRE(res.status == SolveStatus::Failed);
}

TEST_CASE("rectangle profile builds a planar face", "[sketch][profile]") {
    Sketch sk("Rect");
    auto b = sk.add_line(0, 0, 40, 0);
    auto r = sk.add_line(40, 0, 40, 30);
    auto t = sk.add_line(40, 30, 0, 30);
    auto l = sk.add_line(0, 30, 0, 0);
    (void)b; (void)r; (void)t; (void)l;

    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(shape::area(face) == Approx(1200.0).epsilon(1e-6));
}

TEST_CASE("circle profile builds a disk", "[sketch][profile]") {
    Sketch sk("Disk");
    sk.add_circle(0, 0, 10);
    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(shape::area(face) == Approx(3.14159265358979 * 100).epsilon(1e-4));
}

TEST_CASE("open profile fails cleanly", "[sketch][profile]") {
    Sketch sk("Open");
    sk.add_line(0, 0, 10, 0);
    sk.add_line(10, 0, 10, 10);
    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(face.IsNull());
    REQUIRE(!err.empty());
}

TEST_CASE("construction geometry is excluded from profiles", "[sketch][profile]") {
    Sketch sk("Constr");
    sk.add_circle(0, 0, 10);
    auto guide = sk.add_line(-50, 0, 50, 0);
    sk.set_construction(guide, true);
    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());  // circle alone forms the profile
}

TEST_CASE("multi-wire profile: outer rect minus inner hole", "[sketch][profile]") {
    Sketch sk("Frame");
    // Outer 40x30
    sk.add_line(0, 0, 40, 0);
    sk.add_line(40, 0, 40, 30);
    sk.add_line(40, 30, 0, 30);
    sk.add_line(0, 30, 0, 0);
    // Inner 20x10 centered hole
    sk.add_line(10, 10, 30, 10);
    sk.add_line(30, 10, 30, 20);
    sk.add_line(30, 20, 10, 20);
    sk.add_line(10, 20, 10, 10);

    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(err.empty());
    REQUIRE(shape::area(face) == Approx(40.0 * 30.0 - 20.0 * 10.0).epsilon(1e-6));
}

TEST_CASE("multi-wire profile: open leftover fails", "[sketch][profile]") {
    Sketch sk("OpenHole");
    sk.add_line(0, 0, 40, 0);
    sk.add_line(40, 0, 40, 30);
    sk.add_line(40, 30, 0, 30);
    sk.add_line(0, 30, 0, 0);
    // Incomplete inner loop
    sk.add_line(10, 10, 30, 10);
    sk.add_line(30, 10, 30, 20);

    std::string err;
    TopoDS_Shape face = sk.profile_face(&err);
    REQUIRE(face.IsNull());
    REQUIRE(!err.empty());
}
