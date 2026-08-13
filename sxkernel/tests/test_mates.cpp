#include <catch.hpp>

#include <cmath>
#include <cstdio>
#include <string>

#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/mates.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

namespace {

struct TmpFile {
    std::string path;
    explicit TmpFile(const char* name) : path(std::string("/tmp/sx_test_") + name) {}
    ~TmpFile() { std::remove(path.c_str()); }
};

// First planar face of `body` whose outward normal matches `want` (world
// space, body at rest). Null id when none.
EntityId planar_face_with_normal(const Document& doc, const EntityId& body_id,
                                 const gp_Dir& want) {
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    auto it = b->subshape_ids.find(EntityKind::Face);
    REQUIRE(it != b->subshape_ids.end());
    for (const auto& fid : it->second) {
        auto pl = mate_plane(doc, {}, fid);
        if (pl && pl->normal.IsEqual(want, 1e-6)) return fid;
    }
    return {};
}

EntityId cylindrical_face(const Document& doc, const EntityId& body_id) {
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        if (mate_axis(doc, {}, fid)) return fid;
    }
    return {};
}

void world_bbox(const Document& doc, const Instance& inst, double out[6]) {
    Bnd_Box box;
    BRepBndLib::Add(resolved_shape(doc, inst), box);
    box.Get(out[0], out[1], out[2], out[3], out[4], out[5]);
}

}  // namespace

TEST_CASE("plane coincident mate stacks a block onto a base", "[mates]") {
    Document doc;
    // Base 100x100x20 at origin; block 30x30x30 instanced far away, rotated.
    auto base = doc.add_body(shape::make_box(100, 100, 20), "Base");
    auto block = doc.add_body(shape::make_box(30, 30, 30, {{200, 0, 0}}), "Block");
    auto inst = doc.add_instance(block, {50, 50, 90}, {0, 0, 0.3826834, 0.9238795},
                                 "Block-1");  // 45 deg about Z
    REQUIRE(!inst.is_null());

    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_bottom = planar_face_with_normal(doc, block, gp_Dir(0, 0, -1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_bottom.is_null());

    Mate m;
    m.type = MateType::PlaneCoincident;
    m.face_a = base_top;      // grounded body reference (instance_a null)
    m.instance_b = inst;
    m.face_b = block_bottom;
    auto mid = doc.add_mate(m);
    REQUIRE(!mid.is_null());
    REQUIRE(solve_mates(doc));

    // Block bottom now sits on z = 20 (base top).
    double bb[6];
    world_bbox(doc, *doc.instance(inst), bb);
    CHECK(bb[2] == Approx(20.0).margin(1e-6));

    SECTION("offset opens a gap along the mate normal") {
        Mate g = doc.mates().front();
        doc.remove_mate(g.id);
        g.offset = 5.0;
        REQUIRE(!doc.add_mate(g).is_null());
        REQUIRE(solve_mates(doc));
        world_bbox(doc, *doc.instance(inst), bb);
        CHECK(bb[2] == Approx(25.0).margin(1e-6));
    }
}

TEST_CASE("concentric mate drops a pin into a hole axis", "[mates]") {
    Document doc;
    auto hole_cyl = doc.add_body(shape::make_cylinder(10, 40, {{60, 30, 0}}), "Boss");
    auto pin = doc.add_body(shape::make_cylinder(4, 25), "Pin");
    auto inst = doc.add_instance(pin, {-80, 15, 3}, {0, 0.7071068, 0, 0.7071068},
                                 "Pin-1");  // 90 deg about Y: axis now along X
    REQUIRE(!inst.is_null());

    auto boss_face = cylindrical_face(doc, hole_cyl);
    auto pin_face = cylindrical_face(doc, pin);
    REQUIRE(!boss_face.is_null());
    REQUIRE(!pin_face.is_null());

    Mate m;
    m.type = MateType::Concentric;
    m.face_a = boss_face;
    m.instance_b = inst;
    m.face_b = pin_face;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    // Pin axis must be colinear with the boss axis (x=60, y=30, dir Z):
    // bbox is centered on (60, 30) with 4mm radius in x/y.
    double bb[6];
    world_bbox(doc, *doc.instance(inst), bb);
    CHECK((bb[0] + bb[3]) / 2.0 == Approx(60.0).margin(1e-6));
    CHECK((bb[1] + bb[4]) / 2.0 == Approx(30.0).margin(1e-6));
    CHECK(bb[3] - bb[0] == Approx(8.0).margin(1e-4));  // re-aligned to Z
}

TEST_CASE("mate validation and cascade", "[mates]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "B");
    auto inst = doc.add_instance(body, {30, 0, 0}, {0, 0, 0, 1}, "B-1");

    SECTION("instance_b must be an instance") {
        Mate m;
        m.type = MateType::PlaneCoincident;
        m.instance_b = body;  // a body id, not an instance
        CHECK(doc.add_mate(m).is_null());
    }

    SECTION("wrong surface type fails to apply") {
        Mate m;
        m.type = MateType::Concentric;  // box has no cylindrical face
        m.face_a = doc.body(body)->subshape_ids.at(EntityKind::Face).front();
        m.instance_b = inst;
        m.face_b = m.face_a;
        REQUIRE(!doc.add_mate(m).is_null());
        CHECK_FALSE(solve_mates(doc));
    }

    SECTION("removing an instance cascades its mates") {
        Mate m;
        m.type = MateType::Fixed;
        m.instance_b = inst;
        REQUIRE(!doc.add_mate(m).is_null());
        REQUIRE(doc.mates().size() == 1);
        REQUIRE(doc.remove_instance(inst));
        CHECK(doc.mates().empty());
    }
}

TEST_CASE("mates persist through .sxp round trip", "[mates]") {
    TmpFile f("mates.sxp");
    EntityId mate_id, inst_id;
    {
        Document doc;
        auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
        auto top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
        auto block = doc.add_body(shape::make_box(10, 10, 10, {{100, 0, 0}}), "Blk");
        auto bottom = planar_face_with_normal(doc, block, gp_Dir(0, 0, -1));
        inst_id = doc.add_instance(block, {0, 0, 50}, {0, 0, 0, 1}, "Blk-1");
        Mate m;
        m.type = MateType::PlaneCoincident;
        m.face_a = top;
        m.instance_b = inst_id;
        m.face_b = bottom;
        m.offset = 2.5;
        m.flip = false;
        mate_id = doc.add_mate(m);
        REQUIRE(save_sxp(doc, f.path));
    }
    Document loaded;
    REQUIRE(load_sxp(loaded, f.path));
    REQUIRE(loaded.mates().size() == 1);
    const Mate& m = loaded.mates().front();
    CHECK(m.id == mate_id);
    CHECK(m.type == MateType::PlaneCoincident);
    CHECK(m.instance_b == inst_id);
    CHECK(m.offset == Approx(2.5));
    // And it still solves on the loaded document.
    REQUIRE(solve_mates(loaded));
    double bb[6];
    world_bbox(loaded, *loaded.instance(inst_id), bb);
    CHECK(bb[2] == Approx(12.5).margin(1e-6));
}

TEST_CASE("plane parallel mate aligns normals without closing the gap", "[mates]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
    auto block = doc.add_body(shape::make_box(20, 20, 20, {{100, 0, 0}}), "Blk");
    // Tip the block 45° about Y so its +Z face is tilted; parallel should flatten it.
    auto inst = doc.add_instance(block, {0, 0, 40}, {0, 0.3826834, 0, 0.9238795}, "Blk-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_top = planar_face_with_normal(doc, block, gp_Dir(0, 0, 1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_top.is_null());

    Mate m;
    m.type = MateType::PlaneParallel;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = block_top;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto pl = mate_plane(doc, inst, block_top);
    REQUIRE(pl);
    CHECK(std::abs(pl->normal.Dot(gp_Dir(0, 0, 1))) == Approx(1.0).margin(1e-6));
    // Translation remains free after Parallel: we can still drag Z without
    // the mate snapping us back (unlike PlaneCoincident).
    REQUIRE(doc.set_instance_transform(inst, {0, 0, 80}, {0, 0, 0, 1}));
    REQUIRE(solve_mates(doc));
    CHECK(doc.instance(inst)->translation[2] == Approx(80.0).margin(1e-6));
    auto pl2 = mate_plane(doc, inst, block_top);
    REQUIRE(pl2);
    CHECK(std::abs(pl2->normal.Dot(gp_Dir(0, 0, 1))) == Approx(1.0).margin(1e-6));
}

TEST_CASE("distance mate stacks with a visible gap (SW Video 9)", "[mates]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(100, 100, 20), "Base");
    auto block = doc.add_body(shape::make_box(30, 30, 30, {{200, 0, 0}}), "Block");
    auto inst = doc.add_instance(block, {50, 50, 90}, {0, 0, 0, 1}, "Block-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_bottom = planar_face_with_normal(doc, block, gp_Dir(0, 0, -1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_bottom.is_null());

    Mate m;
    m.type = MateType::Distance;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = block_bottom;
    m.offset = 10.0;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    double bb[6];
    world_bbox(doc, *doc.instance(inst), bb);
    // Base top at z=20; distance 10 → block bottom at z=30.
    CHECK(bb[2] == Approx(30.0).margin(1e-6));
    CHECK(to_string(MateType::Distance) == std::string("distance"));
}

TEST_CASE("angle mate sets normal angle (SW Video 10)", "[mates]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
    auto block = doc.add_body(shape::make_box(20, 20, 20, {{100, 0, 0}}), "Blk");
    auto inst = doc.add_instance(block, {0, 0, 40}, {0, 0, 0, 1}, "Blk-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto block_top = planar_face_with_normal(doc, block, gp_Dir(0, 0, 1));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_top.is_null());

    Mate m;
    m.type = MateType::Angle;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = block_top;
    m.offset = 45.0;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto pl = mate_plane(doc, inst, block_top);
    REQUIRE(pl);
    double ang = gp_Vec(gp_Dir(0, 0, 1)).Angle(gp_Vec(pl->normal)) * 180.0 / M_PI;
    CHECK(ang == Approx(45.0).margin(1e-3));
}

TEST_CASE("perpendicular mate forces 90° normals (SW Video 11)", "[mates]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(50, 50, 10), "Base");
    auto block = doc.add_body(shape::make_box(20, 20, 20, {{100, 0, 0}}), "Blk");
    auto inst = doc.add_instance(block, {0, 0, 40}, {0, 0, 0, 1}, "Blk-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    // Use the block's +X face so we aren't already parallel to base top.
    auto block_side = planar_face_with_normal(doc, block, gp_Dir(1, 0, 0));
    REQUIRE(!base_top.is_null());
    REQUIRE(!block_side.is_null());

    Mate m;
    m.type = MateType::Perpendicular;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = block_side;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto pl = mate_plane(doc, inst, block_side);
    REQUIRE(pl);
    CHECK(std::abs(pl->normal.Dot(gp_Dir(0, 0, 1))) == Approx(0.0).margin(1e-6));
}

TEST_CASE("tangent mate seats a cylinder on a plane (SW Video 11)", "[mates]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(80, 80, 10), "Base");
    auto pin = doc.add_body(shape::make_cylinder(5, 30), "Pin");
    // Tip the pin so its axis is not parallel to the base; tangent should flatten
    // and sit the shell on z = 10 + 5.
    auto inst = doc.add_instance(pin, {0, 0, 50}, {0, 0.3826834, 0, 0.9238795}, "Pin-1");
    auto base_top = planar_face_with_normal(doc, base, gp_Dir(0, 0, 1));
    auto pin_face = cylindrical_face(doc, pin);
    REQUIRE(!base_top.is_null());
    REQUIRE(!pin_face.is_null());

    Mate m;
    m.type = MateType::Tangent;
    m.face_a = base_top;
    m.instance_b = inst;
    m.face_b = pin_face;
    REQUIRE(!doc.add_mate(m).is_null());
    REQUIRE(solve_mates(doc));

    auto cyl = mate_cylinder(doc, inst, pin_face);
    REQUIRE(cyl);
    CHECK(std::abs(cyl->dir.Dot(gp_Dir(0, 0, 1))) == Approx(0.0).margin(1e-5));
    double gap = gp_Vec(gp_Pnt(0, 0, 10), cyl->point).Dot(gp_Vec(0, 0, 1));
    CHECK(std::abs(gap) == Approx(5.0).margin(1e-4));
}
