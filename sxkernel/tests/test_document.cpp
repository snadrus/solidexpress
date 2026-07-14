#include <catch.hpp>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("add box body registers subshapes with stable ids", "[document]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 20, 30), "Box 1");

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(b->name == "Box 1");

    auto counts = shape::count(b->shape);
    REQUIRE(counts.faces == 6);
    REQUIRE(counts.edges == 12);
    REQUIRE(counts.vertices == 8);

    REQUIRE(b->subshape_ids.at(EntityKind::Face).size() == 6);
    REQUIRE(b->subshape_ids.at(EntityKind::Edge).size() == 12);
    REQUIRE(b->subshape_ids.at(EntityKind::Vertex).size() == 8);

    // Every subshape id resolves back to a shape of the right type.
    for (int i = 1; i <= 6; ++i) {
        auto fid = doc.subshape_id(body_id, EntityKind::Face, i);
        REQUIRE(!fid.is_null());
        auto shape = doc.resolve(fid);
        REQUIRE(!shape.IsNull());
        REQUIRE(shape.ShapeType() == TopAbs_FACE);
        REQUIRE(doc.owning_body(fid) == body_id);
    }
}

TEST_CASE("volume and validity of primitives", "[document][shape]") {
    auto box = shape::make_box(10, 10, 10);
    REQUIRE(shape::is_valid(box));
    REQUIRE(shape::volume(box) == Approx(1000.0).epsilon(1e-9));

    auto cyl = shape::make_cylinder(5, 10);
    REQUIRE(shape::is_valid(cyl));
    REQUIRE(shape::volume(cyl) == Approx(3.14159265358979 * 25 * 10).epsilon(1e-6));

    auto sph = shape::make_sphere(3);
    REQUIRE(shape::volume(sph) == Approx(4.0 / 3.0 * 3.14159265358979 * 27).epsilon(1e-6));
}

TEST_CASE("remove body clears registry", "[document]") {
    Document doc;
    auto id1 = doc.add_body(shape::make_box(1, 1, 1), "A");
    auto id2 = doc.add_body(shape::make_sphere(1), "B");
    auto face1 = doc.subshape_id(id1, EntityKind::Face, 1);

    REQUIRE(doc.remove_body(id1));
    REQUIRE(doc.body(id1) == nullptr);
    REQUIRE(doc.body_ids().size() == 1);
    REQUIRE(!doc.find_subshape(face1).has_value());
    REQUIRE(doc.resolve(face1).IsNull());
    REQUIRE(doc.body(id2) != nullptr);  // other body untouched
    REQUIRE(!doc.remove_body(id1));     // double delete is a no-op
}

TEST_CASE("brep round trip preserves geometry", "[shape]") {
    auto box = shape::make_box(2, 3, 4);
    auto text = shape::to_brep_string(box);
    REQUIRE(!text.empty());
    auto restored = shape::from_brep_string(text);
    REQUIRE(shape::is_valid(restored));
    REQUIRE(shape::volume(restored) == Approx(24.0).epsilon(1e-9));
}

TEST_CASE("document generates cards for body and faces", "[document][cards]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_cylinder(5, 10), "Cyl 1");

    const Card* bc = doc.cards().find(body_id);
    REQUIRE(bc != nullptr);
    REQUIRE(bc->kind == EntityKind::Body);
    REQUIRE(bc->digest.find("faces") != std::string::npos);

    // Cylinder has 3 faces: lateral, top, bottom.
    const Body* b = doc.body(body_id);
    const auto& face_ids = b->subshape_ids.at(EntityKind::Face);
    REQUIRE(face_ids.size() == 3);
    bool saw_cylindrical = false, saw_planar = false;
    for (const auto& fid : face_ids) {
        const Card* fc = doc.cards().find(fid);
        REQUIRE(fc != nullptr);
        if (fc->digest.find("cylindrical") != std::string::npos) saw_cylindrical = true;
        if (fc->digest.find("planar") != std::string::npos) saw_planar = true;
    }
    REQUIRE(saw_cylindrical);
    REQUIRE(saw_planar);
}
