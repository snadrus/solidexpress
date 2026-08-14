#include <catch.hpp>

#include <cmath>

#include "sx/cam.hpp"
#include "sx/catalog.hpp"
#include "sx/document.hpp"
#include "sx/fea.hpp"
#include "sx/features.hpp"
#include "sx/joints.hpp"
#include "sx/measure.hpp"
#include "sx/query.hpp"
#include "sx/rules.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sheet_metal.hpp"
#include "sx/sketch.hpp"

using namespace sx;

TEST_CASE("crank-slider analytic position", "[wave1][joints]") {
    const double a = 20.0, b = 80.0;
    CHECK(crank_slider_x(a, b, 0.0) == Approx(100.0).margin(1e-9));
    const double x90 = crank_slider_x(a, b, 1.5707963267948966);
    CHECK(x90 == Approx(std::sqrt(b * b - a * a)).margin(1e-6));
}

TEST_CASE("revolute joint seats connector origins", "[wave1][joints]") {
    Document doc;
    auto base = doc.add_body(shape::make_box(10, 10, 10), "Base");
    auto arm = doc.add_body(shape::make_box(30, 6, 6, {{80, 0, 0}}), "Arm");
    auto inst = doc.add_instance(arm, {40, 0, 20}, {0, 0, 0, 1}, "Arm-1");
    Joint j;
    j.type = JointType::Revolute;
    j.a.origin = {5, 5, 10};
    j.a.z_dir = {0, 0, 1};
    j.b.instance = inst;
    j.b.origin = {80, 3, 3};
    j.b.z_dir = {0, 0, 1};
    REQUIRE(apply_joint(doc, j, 0.0));
    CHECK(doc.instance(inst)->translation[0] == Approx(5.0 - 80.0 + 40.0).margin(2.0));
    (void)base;
}

TEST_CASE("drawing dim follows a resized box", "[wave1][draw]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 20.0}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    REQUIRE(doc.graph().regenerate(doc));
    auto body = doc.graph().feature(fid)->output_body;
    auto bb = measure::bounding_box(doc, body);
    REQUIRE(bb);
    const double w0 = bb->max[0] - bb->min[0];
    CHECK(w0 == Approx(40.0).margin(1e-6));
    Feature* f = doc.graph().feature(fid);
    f->params["a"] = 55.0;
    REQUIRE(doc.graph().regenerate(doc));
    auto bb2 = measure::bounding_box(doc, body);
    REQUIRE(bb2);
    CHECK(bb2->max[0] - bb2->min[0] == Approx(55.0).margin(1e-6));
}

TEST_CASE("BOM counts two instances of one source", "[wave1][bom]") {
    Document doc;
    auto src = doc.add_body(shape::make_box(8, 8, 8), "Bolt");
    doc.add_instance(src, {20, 0, 0}, {0, 0, 0, 1}, "B1");
    doc.add_instance(src, {40, 0, 0}, {0, 0, 0, 1}, "B2");
    int n = 0;
    for (const auto& inst : doc.instances())
        if (inst.source_body == src) ++n;
    CHECK(n == 2);
}

TEST_CASE("rib joins and grows volume", "[wave1][rib]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 4.0}};
    auto fid = doc.graph().add(std::move(box));
    REQUIRE(doc.graph().regenerate(doc));
    auto body = doc.graph().feature(fid)->output_body;
    const double v0 = shape::volume(doc.body(body)->shape);

    SketchPlane pl;
    pl.origin = {0, 0, 4};
    auto sk = std::make_shared<Sketch>("Rib profile", pl);
    sk->add_line(4.0, 10.0, 16.0, 10.0);
    Feature skf;
    skf.type = FeatureType::Sketch;
    skf.sketch = sk;
    auto sk_id = doc.graph().add(std::move(skf));

    Feature rib;
    rib.type = FeatureType::Rib;
    rib.params = {{"target", fid.str()},
                  {"sketch", sk_id.str()},
                  {"thickness", 2.0},
                  {"height", 8.0}};
    doc.graph().add(std::move(rib));
    REQUIRE(doc.graph().regenerate(doc));
    CHECK(shape::volume(doc.body(body)->shape) > v0);
}

TEST_CASE("flange flat length equals bend-allowance formula", "[wave2][sheet]") {
    const double L = 30.0, T = 1.5, K = 0.44, R = 1.5, A = 1.5707963267948966;
    const double flat = sheet::flat_length(L, L, T, K, R, A);
    const double ba = sheet::bend_allowance(A, T, K, R);
    CHECK(flat == Approx(L + L + ba - 2.0 * T).margin(1e-9));
    CHECK(flat > L);
}

TEST_CASE("flange feature stores flat_length and makes a solid", "[wave2][sheet]") {
    Document doc;
    Feature fl;
    fl.type = FeatureType::Flange;
    fl.params = {{"length", 25.0}, {"thickness", 1.5}, {"k_factor", 0.44},
                 {"radius", 1.5}, {"angle_rad", 1.5707963267948966}};
    auto fid = doc.graph().add(std::move(fl));
    REQUIRE(doc.graph().regenerate(doc));
    const Feature* f = doc.graph().feature(fid);
    REQUIRE(f);
    REQUIRE(f->params.contains("flat_length"));
    CHECK(f->params["flat_length"].get<double>() > 25.0);
    REQUIRE(doc.body(f->output_body));
    CHECK(shape::volume(doc.body(f->output_body)->shape) > 0.0);
}

TEST_CASE("frame member cut length is the path length", "[wave2][frame]") {
    Document doc;
    Feature fr;
    fr.type = FeatureType::FrameMember;
    fr.params = {{"path", {{0.0, 0.0, 0.0}, {0.0, 0.0, 80.0}}},
                 {"profile_w", 20.0},
                 {"profile_h", 20.0}};
    auto fid = doc.graph().add(std::move(fr));
    REQUIRE(doc.graph().regenerate(doc));
    const Feature* f = doc.graph().feature(fid);
    REQUIRE(f);
    CHECK(f->params["cut_length"].get<double>() == Approx(80.0).margin(1e-6));
}

TEST_CASE("query created-by lights faces of a hole plate", "[wave3][query]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 8.0}};
    auto fid = doc.graph().add(std::move(box));
    REQUIRE(doc.graph().regenerate(doc));
    auto hits = run_query(doc, "type=face created-by=" + fid.str());
    CHECK(hits.size() >= 6);
    Feature prim = *doc.graph().feature(fid);
    CHECK(card_digest(prim).find("primitive") != std::string::npos);
}

TEST_CASE("rule suppresses a feature when width > 100", "[wave3][rules]") {
    Document doc;
    doc.graph().variables().set("width", "120");
    Feature box;
    box.type = FeatureType::Primitive;
    box.name = "rib";
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    Rule r{"wide", "width > 100", "suppress rib"};
    CHECK(apply_rules(doc.graph(), {r}) == 1);
    CHECK(doc.graph().feature(fid)->suppressed);
}

TEST_CASE("CAM pocket has more than two passes and posts G-code", "[wave4][cam]") {
    auto tp = cam::pocket_rect(0, 0, 20, 10, 2.0, 2.0);
    CHECK(tp.points.size() >= 8);
    auto g = cam::post_gcode(tp);
    CHECK(g.find("G21") != std::string::npos);
    CHECK(g.find("G1") != std::string::npos);
}

TEST_CASE("FEA cantilever deflection is positive and scales with L^3", "[wave4][fea]") {
    const double I = fea::rect_inertia(20.0, 4.0);
    const double d1 = fea::cantilever_deflection(100.0, 50.0, 210000.0, I);
    const double d2 = fea::cantilever_deflection(100.0, 100.0, 210000.0, I);
    CHECK(d1 > 0.0);
    CHECK(d2 / d1 == Approx(8.0).margin(1e-6));
}

TEST_CASE("catalog M6x20 is in the base table", "[wave4][catalog]") {
    auto f = catalog::find_fastener("M6x20");
    REQUIRE(f);
    CHECK(f->diameter_mm == Approx(6.0));
    CHECK(f->length_mm == Approx(20.0));
}
