#include <catch.hpp>

#include <cmath>
#include <cstdio>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("featimport: STEP base feature volume, scale, suppress, failure, json",
          "[featimport]") {
    const char* path = "/tmp/sx_featimport_box.step";
    std::remove(path);

    Document src;
    src.add_body(shape::make_box(10, 20, 30), "Box");
    const double box_vol = 10.0 * 20.0 * 30.0;
    std::string err;
    REQUIRE(interop::export_step(src, path, &err));
    REQUIRE(err.empty());

    Document doc;
    FeatureGraph graph;

    Feature imp;
    imp.type = FeatureType::ImportStep;
    imp.params = {{"path", std::string(path)}, {"index", 0}, {"scale", 1.0}};
    auto fid = graph.add(std::move(imp));

    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(fid)->output_body;
    REQUIRE_FALSE(body_id.is_null());
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::volume(b->shape) == Approx(box_vol).epsilon(1e-4));

    // Scale 2 → linear ×2 ⇒ volume ×8.
    json p = graph.feature(fid)->params;
    p["scale"] = 2.0;
    REQUIRE(graph.set_params(fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(box_vol * 8.0).epsilon(1e-4));

    // Suppress → body gone; unsuppress restores stable id and volume.
    REQUIRE(graph.set_suppressed(fid, true));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) == nullptr);

    REQUIRE(graph.set_suppressed(fid, false));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(fid)->output_body == body_id);
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(box_vol * 8.0).epsilon(1e-4));

    // Bogus path → regenerate reports failure without crashing.
    FeatureGraph bad;
    Feature bad_f;
    bad_f.type = FeatureType::ImportStep;
    bad_f.params = {{"path", "/tmp/sx_featimport_missing_nope.step"}, {"index", 0}};
    bad.add(std::move(bad_f));
    Document bad_doc;
    err.clear();
    REQUIRE_FALSE(bad.regenerate(bad_doc, &err));
    REQUIRE_FALSE(err.empty());
    REQUIRE(bad_doc.body_ids().empty());

    // Bad index → failure.
    FeatureGraph bad_idx;
    Feature bad_i;
    bad_i.type = FeatureType::ImportStep;
    bad_i.params = {{"path", std::string(path)}, {"index", 99}};
    bad_idx.add(std::move(bad_i));
    Document idx_doc;
    err.clear();
    REQUIRE_FALSE(bad_idx.regenerate(idx_doc, &err));
    REQUIRE(err.find("index") != std::string::npos);

    // JSON round-trip.
    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.timeline().size() == graph.timeline().size());
    REQUIRE(restored.feature(fid)->type == FeatureType::ImportStep);
    REQUIRE(restored.feature(fid)->params == graph.feature(fid)->params);
    REQUIRE(restored.feature(fid)->output_body == body_id);

    Document doc2;
    REQUIRE(restored.regenerate(doc2, &err));
    REQUIRE(doc2.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc2.body(body_id)->shape) ==
            Approx(shape::volume(doc.body(body_id)->shape)).epsilon(1e-6));

    REQUIRE(std::string(to_string(FeatureType::ImportStep)) == "import_step");
    REQUIRE(feature_type_from_string("import_step") == FeatureType::ImportStep);

    std::remove(path);
}
