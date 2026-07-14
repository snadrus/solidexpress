#include <catch.hpp>

#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

TEST_CASE("featorder: move rejects dependency violations", "[featorder]") {
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));

    Feature cyl;
    cyl.type = FeatureType::Primitive;
    cyl.params = {{"kind", "cylinder"},
                  {"a", 8.0},
                  {"b", 30.0},
                  {"c", 0.0},
                  {"origin", json::array({20.0, 20.0, 0.0})}};
    auto cyl_fid = graph.add(std::move(cyl));

    Feature cut;
    cut.type = FeatureType::Boolean;
    cut.params = {{"op", "cut"}, {"target", box_fid.str()}, {"tool", cyl_fid.str()}};
    auto cut_fid = graph.add(std::move(cut));

    REQUIRE(graph.timeline().size() == 3);
    // Cut depends on both primitives — cannot move before its tool (or target).
    REQUIRE_FALSE(graph.move(cut_fid, 0));
    REQUIRE_FALSE(graph.move(cut_fid, 1));
    REQUIRE(graph.timeline()[0].id == box_fid);
    REQUIRE(graph.timeline()[1].id == cyl_fid);
    REQUIRE(graph.timeline()[2].id == cut_fid);

    // Cannot move a primitive after the cut that depends on it.
    REQUIRE_FALSE(graph.move(box_fid, 2));
    REQUIRE_FALSE(graph.move(cyl_fid, 2));
    REQUIRE(graph.timeline()[0].id == box_fid);
    REQUIRE(graph.timeline()[1].id == cyl_fid);
}

TEST_CASE("featorder: swap independent primitives; regenerate volumes match",
          "[featorder]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature cyl;
    cyl.type = FeatureType::Primitive;
    cyl.params = {{"kind", "cylinder"},
                  {"a", 5.0},
                  {"b", 20.0},
                  {"c", 0.0},
                  {"origin", json::array({50.0, 0.0, 0.0})}};
    auto cyl_fid = graph.add(std::move(cyl));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId box_body = graph.feature(box_fid)->output_body;
    EntityId cyl_body = graph.feature(cyl_fid)->output_body;
    const double vol_box = shape::volume(doc.body(box_body)->shape);
    const double vol_cyl = shape::volume(doc.body(cyl_body)->shape);
    REQUIRE(vol_box == Approx(1000.0));
    REQUIRE(vol_cyl == Approx(M_PI * 25.0 * 20.0).epsilon(1e-6));

    REQUIRE(graph.move(cyl_fid, 0));
    REQUIRE(graph.timeline()[0].id == cyl_fid);
    REQUIRE(graph.timeline()[1].id == box_fid);

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(box_body) != nullptr);
    REQUIRE(doc.body(cyl_body) != nullptr);
    REQUIRE(shape::volume(doc.body(box_body)->shape) == Approx(vol_box));
    REQUIRE(shape::volume(doc.body(cyl_body)->shape) == Approx(vol_cyl).epsilon(1e-6));
    REQUIRE(graph.feature(box_fid)->output_body == box_body);
    REQUIRE(graph.feature(cyl_fid)->output_body == cyl_body);
}

TEST_CASE("featorder: boolean cut + swap primitives keeps stable body ids",
          "[featorder]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"},
                  {"a", 40.0},
                  {"b", 40.0},
                  {"c", 20.0},
                  {"origin", json::array({0.0, 0.0, 0.0})}};
    auto box_fid = graph.add(std::move(box));

    Feature cyl;
    cyl.type = FeatureType::Primitive;
    cyl.params = {{"kind", "cylinder"},
                  {"a", 8.0},
                  {"b", 30.0},
                  {"c", 0.0},
                  {"origin", json::array({20.0, 20.0, -5.0})}};
    auto cyl_fid = graph.add(std::move(cyl));

    Feature cut;
    cut.type = FeatureType::Boolean;
    cut.params = {{"op", "cut"}, {"target", box_fid.str()}, {"tool", cyl_fid.str()}};
    auto cut_fid = graph.add(std::move(cut));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId box_body = graph.feature(box_fid)->output_body;
    EntityId cyl_body = graph.feature(cyl_fid)->output_body;
    REQUIRE(doc.body(box_body) != nullptr);
    // Tool is consumed by boolean cut.
    REQUIRE(doc.body(cyl_body) == nullptr);
    const double vol_cut = shape::volume(doc.body(box_body)->shape);

    REQUIRE_FALSE(graph.move(cut_fid, 0));
    REQUIRE_FALSE(graph.move(cut_fid, 1));

    // Swapping the two primitives (both before the cut) is allowed.
    REQUIRE(graph.move(cyl_fid, 0));
    REQUIRE(graph.timeline()[0].id == cyl_fid);
    REQUIRE(graph.timeline()[1].id == box_fid);
    REQUIRE(graph.timeline()[2].id == cut_fid);

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(box_fid)->output_body == box_body);
    REQUIRE(graph.feature(cyl_fid)->output_body == cyl_body);
    REQUIRE(doc.body(box_body) != nullptr);
    REQUIRE(doc.body(cyl_body) == nullptr);  // still consumed
    REQUIRE(shape::volume(doc.body(box_body)->shape) == Approx(vol_cut).epsilon(1e-6));
    // No orphaned bodies.
    REQUIRE(doc.body_ids().size() == 1);
}

TEST_CASE("featorder: rename persists through JSON round-trip", "[featorder]") {
    FeatureGraph graph;
    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 5.0}, {"b", 5.0}, {"c", 5.0}};
    auto fid = graph.add(std::move(box));
    REQUIRE(graph.rename(fid, "MainBlock"));
    REQUIRE(graph.feature(fid)->name == "MainBlock");

    FeatureGraph restored = FeatureGraph::from_json(graph.to_json());
    REQUIRE(restored.feature(fid) != nullptr);
    REQUIRE(restored.feature(fid)->name == "MainBlock");
    // Order is implicit in timeline array.
    REQUIRE(restored.timeline().size() == 1);
    REQUIRE(restored.timeline()[0].id == fid);

    REQUIRE_FALSE(graph.rename(EntityId::generate(), "Nope"));
}
