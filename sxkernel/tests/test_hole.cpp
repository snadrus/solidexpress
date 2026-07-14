#include <catch.hpp>

#include <cmath>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/commands_hole.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("simple through hole decreases volume by cylinder", "[hole]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(20, 20, 10), "Plate");

    const double vol0 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol0 == Approx(4000.0));

    // Drill from top center downward through the 10 mm plate.
    HoleCommand cmd(body_id, gp_Pnt(10, 10, 10), gp_Dir(0, 0, -1), 6.0, 0.0);
    REQUIRE(cmd.try_execute(doc));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::count(b->shape).solids == 1);

    const double expected_drop = M_PI * 9.0 * 10.0;
    const double vol1 = shape::volume(b->shape);
    REQUIRE(vol0 - vol1 == Approx(expected_drop).epsilon(0.01));

    // Undo via command directly (snapshot restore).
    cmd.undo(doc);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol0).epsilon(1e-9));

    cmd.redo(doc);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol1).epsilon(1e-9));
}

TEST_CASE("counterbore through hole removes CB shoulder volume", "[hole]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(20, 20, 10), "Plate");
    const double vol0 = shape::volume(doc.body(body_id)->shape);

    HoleCommand cmd(body_id, gp_Pnt(10, 10, 10), gp_Dir(0, 0, -1), 6.0, 0.0,
                    HoleType::Counterbore, 10.0, 3.0);
    REQUIRE(cmd.try_execute(doc));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::count(b->shape).solids == 1);

    // Through hole + annular counterbore shoulder.
    const double expected_drop = M_PI * 9.0 * 10.0 + M_PI * (25.0 - 9.0) * 3.0;
    const double vol1 = shape::volume(b->shape);
    REQUIRE(vol0 - vol1 == Approx(expected_drop).epsilon(0.015));
}

TEST_CASE("countersink removes more volume than simple hole", "[hole]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(20, 20, 10), "Plate");
    const double vol0 = shape::volume(doc.body(body_id)->shape);

    HoleCommand simple(body_id, gp_Pnt(10, 10, 10), gp_Dir(0, 0, -1), 6.0, 0.0);
    REQUIRE(simple.try_execute(doc));
    const double vol_simple = shape::volume(doc.body(body_id)->shape);
    simple.undo(doc);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol0).epsilon(1e-9));

    HoleCommand cs(body_id, gp_Pnt(10, 10, 10), gp_Dir(0, 0, -1), 6.0, 0.0,
                   HoleType::Countersink, 12.0, M_PI / 2.0);
    REQUIRE(cs.try_execute(doc));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::count(b->shape).solids == 1);
    const double vol_cs = shape::volume(b->shape);
    REQUIRE(vol_cs < vol_simple);
    REQUIRE(vol_cs > 0.0);
}

TEST_CASE("hole with bogus body id returns false", "[hole]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(20, 20, 10), "Plate");
    const double vol0 = shape::volume(doc.body(body_id)->shape);

    EntityId bogus = EntityId::generate();
    HoleCommand cmd(bogus, gp_Pnt(10, 10, 10), gp_Dir(0, 0, -1), 6.0, 0.0);
    REQUIRE_FALSE(cmd.try_execute(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol0).epsilon(1e-9));
}
