#include <catch.hpp>
#include <cmath>

#include "sx/sketch.hpp"
#include "sx/sketch_tools.hpp"

using namespace sx;
using namespace sx::sketch_tools;

TEST_CASE("fillet_corner rounds a perpendicular L", "[sketchtools]") {
    Sketch sk("FilletL");
    auto la = sk.add_line(0, 0, 10, 0);
    auto lb = sk.add_line(10, 0, 10, 10);
    size_t n_before = sk.entities().size();

    std::string arc_id = fillet_corner(sk, la.str(), lb.str(), 3.0);
    REQUIRE_FALSE(arc_id.empty());
    REQUIRE(sk.entities().size() == n_before + 1);

    EntityId aid = EntityId::from_string(arc_id);
    const SketchEntity* arc = sk.entity(aid);
    REQUIRE(arc != nullptr);
    REQUIRE(arc->type == SketchEntityType::Arc);
    REQUIRE(sk.param(arc->params[2]) == Approx(3.0).margin(1e-9));

    // Trimmed ends are 3 units from the old corner (10, 0).
    auto a_end = *sk.point_pos({la, PointRole::End});
    auto b_start = *sk.point_pos({lb, PointRole::Start});
    REQUIRE(std::hypot(a_end[0] - 10.0, a_end[1] - 0.0) == Approx(3.0).margin(1e-9));
    REQUIRE(std::hypot(b_start[0] - 10.0, b_start[1] - 0.0) == Approx(3.0).margin(1e-9));

    auto arc_s = *sk.point_pos({aid, PointRole::Start});
    auto arc_e = *sk.point_pos({aid, PointRole::End});
    auto dist = [](std::array<double, 2> p, std::array<double, 2> q) {
        return std::hypot(p[0] - q[0], p[1] - q[1]);
    };
    bool match =
        (dist(arc_s, a_end) < 1e-9 && dist(arc_e, b_start) < 1e-9) ||
        (dist(arc_s, b_start) < 1e-9 && dist(arc_e, a_end) < 1e-9);
    REQUIRE(match);
}

TEST_CASE("fillet_corner fails when lines do not touch", "[sketchtools]") {
    Sketch sk("NoTouch");
    auto la = sk.add_line(0, 0, 10, 0);
    auto lb = sk.add_line(10, 1, 10, 10);
    size_t n_before = sk.entities().size();

    std::string arc_id = fillet_corner(sk, la.str(), lb.str(), 2.0);
    REQUIRE(arc_id.empty());
    REQUIRE(sk.entities().size() == n_before);
}

TEST_CASE("fillet_corner fails when radius exceeds segment", "[sketchtools]") {
    Sketch sk("BigR");
    auto la = sk.add_line(0, 0, 10, 0);
    auto lb = sk.add_line(10, 0, 10, 10);
    size_t n_before = sk.entities().size();

    std::string arc_id = fillet_corner(sk, la.str(), lb.str(), 12.0);
    REQUIRE(arc_id.empty());
    REQUIRE(sk.entities().size() == n_before);
}

TEST_CASE("offset_entities offsets a line by +2", "[sketchtools]") {
    Sketch sk("OffLine");
    auto la = sk.add_line(0, 0, 10, 0);
    auto ids = offset_entities(sk, {la.str()}, 2.0);
    REQUIRE(ids.size() == 1);

    EntityId nid = EntityId::from_string(ids[0]);
    const SketchEntity* ne = sk.entity(nid);
    REQUIRE(ne != nullptr);
    REQUIRE(ne->type == SketchEntityType::Line);

    // Original untouched; left of +X is +Y, so offset line at y=2.
    auto o0 = *sk.point_pos({la, PointRole::Start});
    auto o1 = *sk.point_pos({la, PointRole::End});
    REQUIRE(o0[0] == Approx(0.0));
    REQUIRE(o0[1] == Approx(0.0));
    REQUIRE(o1[0] == Approx(10.0));
    REQUIRE(o1[1] == Approx(0.0));

    auto n0 = *sk.point_pos({nid, PointRole::Start});
    auto n1 = *sk.point_pos({nid, PointRole::End});
    REQUIRE(n0[0] == Approx(0.0).margin(1e-9));
    REQUIRE(n0[1] == Approx(2.0).margin(1e-9));
    REQUIRE(n1[0] == Approx(10.0).margin(1e-9));
    REQUIRE(n1[1] == Approx(2.0).margin(1e-9));
    REQUIRE(std::hypot(n0[0] - o0[0], n0[1] - o0[1]) == Approx(2.0).margin(1e-9));
    REQUIRE(std::hypot(n1[0] - o1[0], n1[1] - o1[1]) == Approx(2.0).margin(1e-9));
}

TEST_CASE("offset_entities offsets and skips circles by radius", "[sketchtools]") {
    Sketch sk("OffCirc");
    auto c = sk.add_circle(1, 2, 5);

    auto ok = offset_entities(sk, {c.str()}, -2.0);
    REQUIRE(ok.size() == 1);
    EntityId nid = EntityId::from_string(ok[0]);
    const SketchEntity* ne = sk.entity(nid);
    REQUIRE(ne->type == SketchEntityType::Circle);
    REQUIRE(sk.param(ne->params[0]) == Approx(1.0));
    REQUIRE(sk.param(ne->params[1]) == Approx(2.0));
    REQUIRE(sk.param(ne->params[2]) == Approx(3.0).margin(1e-9));

    // Original still r=5.
    REQUIRE(sk.param(sk.entity(c)->params[2]) == Approx(5.0));

    size_t n_before = sk.entities().size();
    auto bad = offset_entities(sk, {c.str()}, -6.0);
    REQUIRE(bad.empty());
    REQUIRE(sk.entities().size() == n_before);
}
