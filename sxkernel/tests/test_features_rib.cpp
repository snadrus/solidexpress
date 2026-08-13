#include <catch.hpp>
#include <cmath>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

TEST_CASE("rib fuses a thin stiffener into a box", "[featrib]") {
    Document doc;
    FeatureGraph graph;

    Feature base;
    base.type = FeatureType::Primitive;
    base.params = {{"kind", "box"}, {"a", 40.0}, {"b", 40.0}, {"c", 20.0}};
    auto base_fid = graph.add(std::move(base));

    // Open line on the top plane (z=20) across the box.
    Feature skf;
    skf.type = FeatureType::Sketch;
    SketchPlane pl;
    pl.origin = {0, 0, 20};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    skf.sketch = std::make_shared<Sketch>("RibSketch", pl);
    skf.sketch->add_line(5, 20, 35, 20);
    auto sketch_fid = graph.add(std::move(skf));

    Feature rib;
    rib.type = FeatureType::Rib;
    rib.params = {{"sketch", sketch_fid.str()},
                  {"target", base_fid.str()},
                  {"thickness", 2.0},
                  {"height", 15.0}};
    graph.add(std::move(rib));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(base_fid)->output_body;
    double base_vol = 40.0 * 40.0 * 20.0;
    double vol = shape::volume(doc.body(body_id)->shape);
    // Outward fin: ~ length(30) * thickness(2) * height(15) = 900.
    CHECK(vol == Approx(base_vol + 900.0).margin(50.0));
}
