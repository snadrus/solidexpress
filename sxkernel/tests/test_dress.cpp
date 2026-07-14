#include <catch.hpp>

#include "sx/commands_dress.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("fillet one edge of a box", "[dress]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    const Body* b0 = doc.body(body_id);
    REQUIRE(shape::volume(b0->shape) == Approx(1000.0));
    REQUIRE(shape::count(b0->shape).faces == 6);

    const auto edge_ids_before = b0->subshape_ids.at(EntityKind::Edge);
    REQUIRE(edge_ids_before.size() == 12);
    EntityId edge = edge_ids_before.front();

    stack.push(doc, std::make_unique<FilletCommand>(std::vector<EntityId>{edge}, 2.0));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    const double vol = shape::volume(b->shape);
    // Removed material ≈ (4-pi)/4 * r^2 * length ≈ 8.58 for r=2, L=10
    REQUIRE(vol < 1000.0);
    REQUIRE(vol > 990.0);
    REQUIRE(shape::count(b->shape).faces == 7);

    REQUIRE(stack.undo(doc));
    b = doc.body(body_id);
    REQUIRE(shape::volume(b->shape) == Approx(1000.0).epsilon(1e-6));
    REQUIRE(b->subshape_ids.at(EntityKind::Edge) == edge_ids_before);

    REQUIRE(stack.redo(doc));
    b = doc.body(body_id);
    REQUIRE(shape::volume(b->shape) == Approx(vol).epsilon(1e-6));
    REQUIRE(shape::count(b->shape).faces == 7);
}

TEST_CASE("fillet all 12 edges of a box", "[dress]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    const auto& edge_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Edge);
    REQUIRE(edge_ids.size() == 12);

    stack.push(doc, std::make_unique<FilletCommand>(edge_ids, 1.0));

    const Body* b = doc.body(body_id);
    REQUIRE(shape::is_valid(b->shape));
    const double vol = shape::volume(b->shape);
    REQUIRE(vol < 1000.0);
    REQUIRE(vol > 950.0);
}

TEST_CASE("chamfer one edge of a box", "[dress]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    EntityId edge = doc.body(body_id)->subshape_ids.at(EntityKind::Edge).front();

    stack.push(doc, std::make_unique<ChamferCommand>(std::vector<EntityId>{edge}, 2.0));

    const Body* b = doc.body(body_id);
    const double vol = shape::volume(b->shape);
    // Symmetric chamfer d=2 on a 90° edge removes 0.5*d^2*L = 20 → vol ≈ 980
    REQUIRE(vol > 970.0);
    REQUIRE(vol < 990.0);
    REQUIRE(shape::count(b->shape).faces == 7);

    REQUIRE(stack.undo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));

    REQUIRE(stack.redo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol).epsilon(1e-6));
    REQUIRE(shape::count(doc.body(body_id)->shape).faces == 7);
}

TEST_CASE("fillet rejects non-edge and oversized radius", "[dress]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");
    EntityId face = doc.body(body_id)->subshape_ids.at(EntityKind::Face).front();
    EntityId edge = doc.body(body_id)->subshape_ids.at(EntityKind::Edge).front();

    FilletCommand bad_kind({face}, 1.0);
    REQUIRE_THROWS_AS(bad_kind.execute(doc), std::invalid_argument);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));

    FilletCommand too_big({edge}, 20.0);
    REQUIRE_THROWS(too_big.execute(doc));
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1000.0).epsilon(1e-6));
}
