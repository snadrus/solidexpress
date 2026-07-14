#include <catch.hpp>
#include <cmath>

#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch_json.hpp"
#include "sx/solver.hpp"

using namespace sx;
using nlohmann::json;

namespace {

// Closed 40×30 rectangle (same geometry as the profile test in test_sketch).
void add_rectangle(Sketch& sk, double w, double h) {
    sk.add_line(0, 0, w, 0);
    sk.add_line(w, 0, w, h);
    sk.add_line(w, h, 0, h);
    sk.add_line(0, h, 0, 0);
}

}  // namespace

TEST_CASE("construction diagonal excluded from rectangle profile", "[construction]") {
    constexpr double w = 40.0, h = 30.0;

    Sketch plain("PlainRect");
    add_rectangle(plain, w, h);
    std::string err_plain;
    TopoDS_Shape face_plain = plain.profile_face(&err_plain);
    REQUIRE(!face_plain.IsNull());
    REQUIRE(shape::area(face_plain) == Approx(w * h).epsilon(1e-6));

    Sketch with_diag("RectPlusDiag");
    add_rectangle(with_diag, w, h);
    auto diag = with_diag.add_line(0, 0, w, h);
    with_diag.set_construction(diag, true);
    REQUIRE(with_diag.is_construction(diag));

    std::string err;
    TopoDS_Shape face = with_diag.profile_face(&err);
    REQUIRE(!face.IsNull());
    REQUIRE(err.empty());
    REQUIRE(shape::area(face) == Approx(w * h).epsilon(1e-6));
    REQUIRE(shape::area(face) == Approx(shape::area(face_plain)).epsilon(1e-6));
}

TEST_CASE("set_construction / is_construction round-trip", "[construction]") {
    Sketch sk("Flags");
    auto a = sk.add_line(0, 0, 10, 0);
    auto b = sk.add_line(0, 0, 0, 10);

    REQUIRE_FALSE(sk.is_construction(a));
    REQUIRE_FALSE(sk.is_construction(b));

    sk.set_construction(a, true);
    REQUIRE(sk.is_construction(a));
    REQUIRE_FALSE(sk.is_construction(b));

    sk.set_construction(a, false);
    REQUIRE_FALSE(sk.is_construction(a));

    // Unknown id is not construction.
    REQUIRE_FALSE(sk.is_construction(EntityId::generate()));
}

TEST_CASE("construction flag survives JSON round-trip", "[construction]") {
    Sketch sk("Json");
    auto normal = sk.add_line(0, 0, 5, 0);
    auto guide = sk.add_circle(0, 0, 3);
    sk.set_construction(guide, true);

    auto restored = sketch_from_json(sketch_to_json(sk));
    REQUIRE_FALSE(restored->is_construction(normal));
    REQUIRE(restored->is_construction(guide));
    REQUIRE(restored->entity(guide)->construction);
}

TEST_CASE("missing construction key defaults to false", "[construction]") {
    Sketch sk("Legacy");
    auto line = sk.add_line(0, 0, 8, 0);
    sk.set_construction(line, true);

    json j = sketch_to_json(sk);
    REQUIRE(j["entities"].is_array());
    REQUIRE(j["entities"].size() == 1);
    REQUIRE(j["entities"][0].contains("construction"));
    j["entities"][0].erase("construction");

    auto restored = sketch_from_json(j);
    REQUIRE(restored->entity(line) != nullptr);
    REQUIRE_FALSE(restored->is_construction(line));
    REQUIRE_FALSE(restored->entity(line)->construction);
}

TEST_CASE("constraint involving construction line still solves", "[construction]") {
    // Horizontal base + construction guide; Parallel drives the guide parallel
    // to the base (id-based refs — construction flag is irrelevant to solver).
    Sketch sk("ConstrSolve");
    auto base = sk.add_line(0, 0, 40, 0);
    auto guide = sk.add_line(5, 5, 35, 20);
    sk.set_construction(guide, true);

    sk.add_constraint(ConstraintType::Horizontal, {{base, PointRole::Self}});
    sk.add_constraint(ConstraintType::Parallel,
                      {{base, PointRole::Self}, {guide, PointRole::Self}});

    auto solver = make_planegcs_backend();
    SolveResult res = solver->solve(sk);
    REQUIRE(res.ok());

    auto g0 = *sk.point_pos({guide, PointRole::Start});
    auto g1 = *sk.point_pos({guide, PointRole::End});
    // Parallel to horizontal base => equal y at both ends of the guide.
    REQUIRE(g0[1] == Approx(g1[1]).margin(1e-6));
    REQUIRE(sk.is_construction(guide));
}
