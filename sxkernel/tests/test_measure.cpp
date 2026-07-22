#include <catch.hpp>

#include <cmath>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("min_distance between boxes", "[measure]") {
    Document doc;
    auto a = doc.add_body(shape::make_box(10, 10, 10), "A");
    shape::Placement p;
    p.origin = {40, 0, 0};
    auto b = doc.add_body(shape::make_box(10, 10, 10, p), "B");

    auto d = measure::min_distance(doc, a, b);
    REQUIRE(d.has_value());
    REQUIRE(d->distance == Approx(30.0).margin(1e-9));

    auto c = doc.add_body(shape::make_box(10, 10, 10), "Overlap");
    auto d0 = measure::min_distance(doc, a, c);
    REQUIRE(d0.has_value());
    REQUIRE(d0->distance == Approx(0.0).margin(1e-9));
}

TEST_CASE("closest_point foot of perpendicular onto a box face", "[measure]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    // Point floating above the top face center → foot at (5,5,10).
    auto r = measure::closest_point(doc, id, {5.0, 5.0, 25.0});
    REQUIRE(r.has_value());
    REQUIRE(r->distance == Approx(15.0).margin(1e-6));
    REQUIRE(r->point_b[0] == Approx(5.0).margin(1e-6));
    REQUIRE(r->point_b[1] == Approx(5.0).margin(1e-6));
    REQUIRE(r->point_b[2] == Approx(10.0).margin(1e-6));
}

TEST_CASE("face_midpoint is UV center of box top", "[measure]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    // Pick the face whose midpoint is on z=10 (top) among the six faces.
    std::optional<std::array<double, 3>> top;
    for (int i = 1; i <= 6; ++i) {
        auto fid = doc.subshape_id(id, EntityKind::Face, i);
        auto mid = measure::face_midpoint(doc, fid);
        REQUIRE(mid.has_value());
        if (std::abs((*mid)[2] - 10.0) < 1e-4) {
            top = mid;
            break;
        }
    }
    REQUIRE(top.has_value());
    REQUIRE((*top)[0] == Approx(5.0).margin(1e-4));
    REQUIRE((*top)[1] == Approx(5.0).margin(1e-4));
    REQUIRE((*top)[2] == Approx(10.0).margin(1e-4));
}

TEST_CASE("bounding_box of origin box", "[measure]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto bb = measure::bounding_box(doc, id);
    REQUIRE(bb.has_value());
    REQUIRE(bb->min[0] == Approx(0.0).margin(1e-4));
    REQUIRE(bb->min[1] == Approx(0.0).margin(1e-4));
    REQUIRE(bb->min[2] == Approx(0.0).margin(1e-4));
    REQUIRE(bb->max[0] == Approx(10.0).margin(1e-4));
    REQUIRE(bb->max[1] == Approx(10.0).margin(1e-4));
    REQUIRE(bb->max[2] == Approx(10.0).margin(1e-4));
}

TEST_CASE("mass_properties of 10mm box", "[measure]") {
    Document doc;
    auto id = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto mp = measure::mass_properties(doc, id);
    REQUIRE(mp.has_value());
    REQUIRE(mp->volume == Approx(1000.0).epsilon(1e-9));
    REQUIRE(mp->surface_area == Approx(600.0).epsilon(1e-9));
    REQUIRE(mp->center_of_mass[0] == Approx(5.0).epsilon(1e-9));
    REQUIRE(mp->center_of_mass[1] == Approx(5.0).epsilon(1e-9));
    REQUIRE(mp->center_of_mass[2] == Approx(5.0).epsilon(1e-9));

    // Diagonal entries equal and positive (cube about COM).
    REQUIRE(mp->inertia[0] == Approx(mp->inertia[4]).epsilon(1e-9));
    REQUIRE(mp->inertia[4] == Approx(mp->inertia[8]).epsilon(1e-9));
    REQUIRE(mp->inertia[0] > 0.0);
}

TEST_CASE("edge_length and face_area of box", "[measure]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto edge = doc.subshape_id(body, EntityKind::Edge, 1);
    auto face = doc.subshape_id(body, EntityKind::Face, 1);

    REQUIRE(measure::edge_length(doc, edge) == Approx(10.0).epsilon(1e-9));
    REQUIRE(measure::face_area(doc, face) == Approx(100.0).epsilon(1e-9));
}

TEST_CASE("angle_between_faces planar normals", "[measure]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    const auto& faces = doc.body(body)->subshape_ids.at(EntityKind::Face);

    bool found_adjacent = false;
    bool found_opposite = false;
    for (size_t i = 0; i < faces.size(); ++i) {
        for (size_t j = i + 1; j < faces.size(); ++j) {
            auto ang = measure::angle_between_faces(doc, faces[i], faces[j]);
            REQUIRE(ang.has_value());
            if (std::abs(*ang - M_PI / 2.0) < 1e-9) found_adjacent = true;
            if (std::abs(*ang - M_PI) < 1e-9) found_opposite = true;
        }
    }
    REQUIRE(found_adjacent);
    REQUIRE(found_opposite);

    // Planar + cylindrical → nullopt.
    auto cyl = doc.add_body(shape::make_cylinder(5, 10), "Cyl");
    EntityId planar, cylindrical;
    for (const auto& fid : doc.body(cyl)->subshape_ids.at(EntityKind::Face)) {
        const Card* c = doc.cards().find(fid);
        REQUIRE(c != nullptr);
        if (c->digest.find("planar") != std::string::npos) planar = fid;
        if (c->digest.find("cylindrical") != std::string::npos) cylindrical = fid;
    }
    REQUIRE(!planar.is_null());
    REQUIRE(!cylindrical.is_null());
    REQUIRE_FALSE(measure::angle_between_faces(doc, planar, cylindrical).has_value());
}

TEST_CASE("invalid ids return nullopt or zero", "[measure]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    EntityId bogus = EntityId::generate();

    REQUIRE_FALSE(measure::min_distance(doc, body, bogus).has_value());
    REQUIRE_FALSE(measure::closest_point(doc, bogus, {0, 0, 0}).has_value());
    REQUIRE_FALSE(measure::face_midpoint(doc, bogus).has_value());
    REQUIRE_FALSE(measure::bounding_box(doc, bogus).has_value());
    REQUIRE_FALSE(measure::mass_properties(doc, bogus).has_value());
    // Face id is not a body.
    auto face = doc.subshape_id(body, EntityKind::Face, 1);
    REQUIRE_FALSE(measure::mass_properties(doc, face).has_value());

    REQUIRE(measure::edge_length(doc, bogus) == 0.0);
    REQUIRE(measure::edge_length(doc, face) == 0.0);
    REQUIRE(measure::face_area(doc, bogus) == 0.0);
    REQUIRE(measure::face_area(doc, body) == 0.0);
    REQUIRE_FALSE(measure::angle_between_faces(doc, face, bogus).has_value());
}
