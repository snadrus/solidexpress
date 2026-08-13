#include <catch.hpp>

#include "sx/document.hpp"
#include "sx/mate_connectors.hpp"
#include "sx/mates.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("implicit connectors on box faces", "[mate_connectors]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(20, 20, 20), "Box");
    auto cons = implicit_connectors(doc);
    // Box: 6 planar faces.
    int planar = 0;
    for (const auto& c : cons) {
        if (c.body == body && c.kind == ConnectorKind::Planar) ++planar;
    }
    CHECK(planar == 6);
}

TEST_CASE("magnetic snap seats instance onto ground face", "[mate_connectors]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(40, 40, 10), "Base");
    auto block = doc.add_body(shape::make_box(10, 10, 10, {{100, 0, 0}}), "Blk");
    // Instance floating above the base, slightly off-center.
    auto inst = doc.add_instance(block, {15, 15, 25}, {0, 0, 0, 1}, "Blk-1");
    REQUIRE(!inst.is_null());

    auto snap = find_connector_snap(doc, inst, 30.0);
    REQUIRE(snap);
    CHECK(snap->mate_type == MateType::PlaneCoincident);
    auto mid = apply_connector_snap(doc, *snap);
    REQUIRE(!mid.is_null());
    REQUIRE(doc.mates().size() == 1);

    // Block should sit on z≈10 (base top).
    const Instance* placed = doc.instance(inst);
    REQUIRE(placed != nullptr);
    CHECK(placed->translation[2] == Approx(10.0).margin(1e-3));
}

TEST_CASE("concentric snap for cylinders", "[mate_connectors]") {
    Document doc;
    auto boss = doc.add_body(shape::make_cylinder(8, 30, {{0, 0, 0}}), "Boss");
    auto pin = doc.add_body(shape::make_cylinder(4, 20), "Pin");
    auto inst = doc.add_instance(pin, {25, 0, 5}, {0, 0, 0, 1}, "Pin-1");
    auto snap = find_connector_snap(doc, inst, 40.0);
    REQUIRE(snap);
    CHECK(snap->mate_type == MateType::Concentric);
    REQUIRE(!apply_connector_snap(doc, *snap).is_null());
    // Pin axis should colinear with boss (x=0,y=0).
    const Instance* p = doc.instance(inst);
    REQUIRE(p);
    CHECK(p->translation[0] == Approx(0.0).margin(1e-3));
    CHECK(p->translation[1] == Approx(0.0).margin(1e-3));
}
