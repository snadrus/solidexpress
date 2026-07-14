#include <catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

double helix_length(double r, double pitch, double turns) {
    return turns * std::sqrt((2.0 * M_PI * r) * (2.0 * M_PI * r) + pitch * pitch);
}

double tube_volume(double profile_r, double r, double pitch, double turns) {
    return M_PI * profile_r * profile_r * helix_length(r, pitch, turns);
}

json helix_params(double profile_r, double r, double pitch, double turns,
                  bool left_handed = false) {
    return {{"profile_radius", profile_r},
            {"axis_point", json::array({0.0, 0.0, 0.0})},
            {"axis_dir", json::array({0.0, 0.0, 1.0})},
            {"radius", r},
            {"pitch", pitch},
            {"turns", turns},
            {"left_handed", left_handed}};
}

}  // namespace

TEST_CASE("feathelix: spring volume, edit pitch, suppress, json, variables",
          "[feathelix]") {
    Document doc;
    FeatureGraph graph;

    const double profile_r = 1.0;
    const double r = 10.0;
    const double pitch = 5.0;
    const double turns = 3.0;

    Feature spring;
    spring.type = FeatureType::HelixSweep;
    spring.params = helix_params(profile_r, r, pitch, turns);
    auto fid = graph.add(std::move(spring));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(fid)->output_body;
    REQUIRE_FALSE(body_id.is_null());
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::count(b->shape).solids >= 1);

    const double expected = tube_volume(profile_r, r, pitch, turns);
    REQUIRE(shape::volume(b->shape) == Approx(expected).epsilon(0.05));

    // Edit pitch via set_params + regenerate → volume tracks new length.
    const double pitch2 = 8.0;
    json p = graph.feature(fid)->params;
    p["pitch"] = pitch2;
    REQUIRE(graph.set_params(fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);
    const double expected2 = tube_volume(profile_r, r, pitch2, turns);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(expected2).epsilon(0.05));

    // Suppressed → body removed; unsuppress restores stable id.
    REQUIRE(graph.set_suppressed(fid, true));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) == nullptr);

    REQUIRE(graph.set_suppressed(fid, false));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(expected2).epsilon(0.05));

    // JSON round-trip.
    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.timeline().size() == graph.timeline().size());
    REQUIRE(restored.feature(fid)->type == FeatureType::HelixSweep);
    REQUIRE(restored.feature(fid)->params == graph.feature(fid)->params);
    REQUIRE(restored.feature(fid)->output_body == body_id);

    Document doc2;
    REQUIRE(restored.regenerate(doc2, &err));
    REQUIRE(doc2.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc2.body(body_id)->shape) ==
            Approx(shape::volume(doc.body(body_id)->shape)).epsilon(1e-6));

    // Variable-driven pitch "=p" with p=5 matches literal 5.
    FeatureGraph lit_graph;
    Feature lit;
    lit.type = FeatureType::HelixSweep;
    lit.params = helix_params(profile_r, r, /*pitch=*/5.0, turns);
    auto lit_fid = lit_graph.add(std::move(lit));

    FeatureGraph var_graph;
    var_graph.variables().set("p", "5");
    Feature var;
    var.type = FeatureType::HelixSweep;
    var.params = helix_params(profile_r, r, /*pitch=*/5.0, turns);
    var.params["pitch"] = "=p";
    auto var_fid = var_graph.add(std::move(var));

    Document lit_doc, var_doc;
    REQUIRE(lit_graph.regenerate(lit_doc, &err));
    REQUIRE(var_graph.regenerate(var_doc, &err));
    const double lit_vol =
        shape::volume(lit_doc.body(lit_graph.feature(lit_fid)->output_body)->shape);
    const double var_vol =
        shape::volume(var_doc.body(var_graph.feature(var_fid)->output_body)->shape);
    REQUIRE(var_vol == Approx(lit_vol).epsilon(1e-6));
    REQUIRE(var_vol == Approx(tube_volume(profile_r, r, 5.0, turns)).epsilon(0.05));
}

TEST_CASE("feathelix: to_string / from_string", "[feathelix]") {
    REQUIRE(std::string(to_string(FeatureType::HelixSweep)) == "helix_sweep");
    REQUIRE(feature_type_from_string("helix_sweep") == FeatureType::HelixSweep);
}
