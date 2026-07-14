#include <catch.hpp>

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>

#include "sx/commands_basic.hpp"
#include "sx/commands_transform.hpp"
#include "sx/document.hpp"
#include "sx/ids.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

namespace {
double dist_from_z_axis(const std::array<double, 3>& com) {
    return std::sqrt(com[0] * com[0] + com[1] * com[1]);
}
}  // namespace

TEST_CASE("mirror body across plane with undo/redo", "[transform]") {
    Document doc;
    CommandStack stack;

    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    // Box spans 0..10; com x=5. Mirror across x=15 → mirrored com x=25.
    auto cmd = std::make_unique<MirrorBodyCommand>(
        body_id, std::array<double, 3>{15, 0, 0}, std::array<double, 3>{1, 0, 0});
    MirrorBodyCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    EntityId mirrored = raw->created_body();
    REQUIRE(doc.body_ids().size() == 2);
    REQUIRE(doc.body(mirrored) != nullptr);
    REQUIRE(shape::volume(doc.body(mirrored)->shape) == Approx(1000.0).epsilon(1e-6));
    auto com = shape::center_of_mass(doc.body(mirrored)->shape);
    REQUIRE(com[0] == Approx(25.0).epsilon(1e-6));

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body_ids().size() == 1);
    REQUIRE(doc.body(mirrored) == nullptr);
    REQUIRE(doc.body(body_id) != nullptr);

    REQUIRE(stack.redo(doc));
    REQUIRE(doc.body_ids().size() == 2);
    REQUIRE(doc.body(mirrored) != nullptr);  // same uuid restored
    REQUIRE(shape::volume(doc.body(mirrored)->shape) == Approx(1000.0).epsilon(1e-6));
}

TEST_CASE("linear pattern along X", "[transform]") {
    Document doc;
    CommandStack stack;

    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    stack.push(doc, std::make_unique<LinearPatternCommand>(
                        body_id, std::array<double, 3>{1, 0, 0}, 20.0, 4));

    REQUIRE(doc.body_ids().size() == 4);

    std::vector<double> xs;
    for (const auto& id : doc.body_ids()) {
        REQUIRE(shape::volume(doc.body(id)->shape) == Approx(1000.0).epsilon(1e-6));
        xs.push_back(shape::center_of_mass(doc.body(id)->shape)[0]);
    }
    std::sort(xs.begin(), xs.end());
    REQUIRE(xs[0] == Approx(5.0).epsilon(1e-6));
    REQUIRE(xs[1] == Approx(25.0).epsilon(1e-6));
    REQUIRE(xs[2] == Approx(45.0).epsilon(1e-6));
    REQUIRE(xs[3] == Approx(65.0).epsilon(1e-6));

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body_ids().size() == 1);
}

TEST_CASE("circular pattern around Z", "[transform]") {
    Document doc;
    CommandStack stack;

    shape::Placement p;
    p.origin = {30, 0, 0};
    auto body_id = doc.add_body(shape::make_box(10, 10, 10, p), "Box");

    stack.push(doc, std::make_unique<CircularPatternCommand>(
                        body_id,
                        std::array<double, 3>{0, 0, 0},
                        std::array<double, 3>{0, 0, 1},
                        6));

    REQUIRE(doc.body_ids().size() == 6);

    std::vector<double> radii;
    for (const auto& id : doc.body_ids()) {
        REQUIRE(shape::volume(doc.body(id)->shape) == Approx(1000.0).epsilon(1e-6));
        radii.push_back(dist_from_z_axis(shape::center_of_mass(doc.body(id)->shape)));
    }
    const double r0 = radii[0];
    for (double r : radii) {
        REQUIRE(r == Approx(r0).epsilon(1e-6));
    }

    REQUIRE(stack.undo(doc));
    REQUIRE(doc.body_ids().size() == 1);
}

TEST_CASE("rotate body in place preserves face ids", "[transform]") {
    Document doc;
    CommandStack stack;

    shape::Placement p;
    p.origin = {30, 0, 0};
    auto body_id = doc.add_body(shape::make_box(10, 10, 10, p), "Box");

    auto faces_before = doc.body(body_id)->subshape_ids.at(EntityKind::Face);
    auto com0 = shape::center_of_mass(doc.body(body_id)->shape);
    // Box at origin {30,0,0} spanning 30..40, 0..10, 0..10 → com ~(35,5,5)
    REQUIRE(com0[0] == Approx(35.0).epsilon(1e-6));
    REQUIRE(com0[1] == Approx(5.0).epsilon(1e-6));
    REQUIRE(com0[2] == Approx(5.0).epsilon(1e-6));

    const double half_pi = M_PI / 2.0;
    stack.push(doc, std::make_unique<RotateBodyCommand>(
                        body_id,
                        std::array<double, 3>{0, 0, 0},
                        std::array<double, 3>{0, 0, 1},
                        half_pi));

    auto com1 = shape::center_of_mass(doc.body(body_id)->shape);
    // 90° about Z: (35,5) → (-5,35)
    REQUIRE(com1[0] == Approx(-5.0).epsilon(1e-6));
    REQUIRE(com1[1] == Approx(35.0).epsilon(1e-6));
    REQUIRE(com1[2] == Approx(5.0).epsilon(1e-6));

    auto faces_after = doc.body(body_id)->subshape_ids.at(EntityKind::Face);
    REQUIRE(faces_after == faces_before);

    REQUIRE(stack.undo(doc));
    auto com2 = shape::center_of_mass(doc.body(body_id)->shape);
    REQUIRE(com2[0] == Approx(35.0).epsilon(1e-6));
    REQUIRE(com2[1] == Approx(5.0).epsilon(1e-6));
    REQUIRE(com2[2] == Approx(5.0).epsilon(1e-6));
}

TEST_CASE("pattern command errors", "[transform]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    EntityId missing;

    LinearPatternCommand bad_count(body_id, {1, 0, 0}, 10.0, 1);
    REQUIRE_THROWS_AS(bad_count.execute(doc), std::invalid_argument);

    LinearPatternCommand bad_body(missing, {1, 0, 0}, 10.0, 3);
    REQUIRE_THROWS_AS(bad_body.execute(doc), std::invalid_argument);

    CircularPatternCommand bad_circ(missing, {0, 0, 0}, {0, 0, 1}, 4);
    REQUIRE_THROWS_AS(bad_circ.execute(doc), std::invalid_argument);
}
