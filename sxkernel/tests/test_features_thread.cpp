#include <catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

json thread_params(const EntityId& target, double major_radius, double pitch, double turns,
                   double depth) {
    return {{"target", target.str()},
            {"axis_point", json::array({0.0, 0.0, 0.0})},
            {"axis_dir", json::array({0.0, 0.0, 1.0})},
            {"major_radius", major_radius},
            {"pitch", pitch},
            {"turns", turns},
            {"depth", depth},
            {"profile_angle_deg", 60.0}};
}

}  // namespace

TEST_CASE("featthread: cut volume, suppress, pitch edit, json, variables", "[featthread]") {
    Document doc;
    FeatureGraph graph;

    const double r = 10.0;
    const double h = 30.0;
    const double major_radius = 10.0;
    const double pitch = 3.0;
    const double turns = 8.0;
    const double depth = 1.5;

    Feature cyl;
    cyl.type = FeatureType::Primitive;
    cyl.params = {{"kind", "cylinder"}, {"a", r}, {"b", h}};
    auto cyl_fid = graph.add(std::move(cyl));

    Feature thread;
    thread.type = FeatureType::Thread;
    thread.params = thread_params(cyl_fid, major_radius, pitch, turns, depth);
    auto thread_fid = graph.add(std::move(thread));

    REQUIRE(graph.has_dependents(cyl_fid));
    REQUIRE(graph.feature(thread_fid)->output_body.is_null());

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(cyl_fid)->output_body;
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::is_valid(doc.body(body_id)->shape));

    const double vol_plain = M_PI * r * r * h;
    const double vol_inner = M_PI * 8.5 * 8.5 * h;
    const double vol_threaded = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol_threaded < vol_plain);
    REQUIRE(vol_threaded > vol_inner);

    // Edit pitch via set_params + regenerate → volume changes.
    json p = graph.feature(thread_fid)->params;
    p["pitch"] = 4.0;
    REQUIRE(graph.set_params(thread_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const double vol_pitch2 = shape::volume(doc.body(body_id)->shape);
    REQUIRE(vol_pitch2 != Approx(vol_threaded).epsilon(1e-9));
    REQUIRE(vol_pitch2 < vol_plain);
    REQUIRE(vol_pitch2 > vol_inner);

    // Suppress → volume restored to plain cylinder.
    REQUIRE(graph.set_suppressed(thread_fid, true));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol_plain).epsilon(1e-6));

    REQUIRE(graph.set_suppressed(thread_fid, false));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol_pitch2).epsilon(1e-6));

    // JSON round-trip.
    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.timeline().size() == graph.timeline().size());
    REQUIRE(restored.feature(thread_fid)->type == FeatureType::Thread);
    REQUIRE(restored.feature(thread_fid)->params == graph.feature(thread_fid)->params);

    Document doc2;
    REQUIRE(restored.regenerate(doc2, &err));
    EntityId body2 = restored.feature(cyl_fid)->output_body;
    REQUIRE(shape::volume(doc2.body(body2)->shape) == Approx(vol_pitch2).epsilon(1e-6));

    // Variable-driven pitch "=p" with p=3 matches literal 3.
    FeatureGraph lit_graph;
    Feature lit_cyl;
    lit_cyl.type = FeatureType::Primitive;
    lit_cyl.params = {{"kind", "cylinder"}, {"a", r}, {"b", h}};
    auto lit_cyl_fid = lit_graph.add(std::move(lit_cyl));
    Feature lit;
    lit.type = FeatureType::Thread;
    lit.params = thread_params(lit_cyl_fid, major_radius, /*pitch=*/3.0, turns, depth);
    auto lit_fid = lit_graph.add(std::move(lit));

    FeatureGraph var_graph;
    var_graph.variables().set("p", "3");
    Feature var_cyl;
    var_cyl.type = FeatureType::Primitive;
    var_cyl.params = {{"kind", "cylinder"}, {"a", r}, {"b", h}};
    auto var_cyl_fid = var_graph.add(std::move(var_cyl));
    Feature var;
    var.type = FeatureType::Thread;
    var.params = thread_params(var_cyl_fid, major_radius, /*pitch=*/3.0, turns, depth);
    var.params["pitch"] = "=p";
    auto var_fid = var_graph.add(std::move(var));
    (void)var_fid;
    (void)lit_fid;

    Document lit_doc, var_doc;
    REQUIRE(lit_graph.regenerate(lit_doc, &err));
    REQUIRE(var_graph.regenerate(var_doc, &err));
    const double lit_vol =
        shape::volume(lit_doc.body(lit_graph.feature(lit_cyl_fid)->output_body)->shape);
    const double var_vol =
        shape::volume(var_doc.body(var_graph.feature(var_cyl_fid)->output_body)->shape);
    REQUIRE(var_vol == Approx(lit_vol).epsilon(1e-6));
}

TEST_CASE("featthread: to_string / from_string", "[featthread]") {
    REQUIRE(std::string(to_string(FeatureType::Thread)) == "thread");
    REQUIRE(feature_type_from_string("thread") == FeatureType::Thread);
}
