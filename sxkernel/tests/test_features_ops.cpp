#include <catch.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

int top_face_index(Document& doc, const EntityId& body_id) {
    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    const auto& faces = b->subshape_ids.at(EntityKind::Face);
    for (size_t i = 0; i < faces.size(); ++i) {
        auto desc = shape::describe_face(doc.resolve(faces[i]));
        if (desc.find("normal (0, 0, 1)") != std::string::npos)
            return static_cast<int>(i + 1);  // 1-based map index
    }
    FAIL("no +Z face found");
    return -1;
}

double dist_from_z_axis(const std::array<double, 3>& com) {
    return std::sqrt(com[0] * com[0] + com[1] * com[1]);
}

}  // namespace

TEST_CASE("featops: mirror regenerates with stable body id", "[featops]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.params = {{"target", box_fid.str()},
                  {"plane_point", json::array({15.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})}};
    auto mir_fid = graph.add(std::move(mir));

    REQUIRE(graph.has_dependents(box_fid));
    REQUIRE(!graph.remove(box_fid));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId mirrored = graph.feature(mir_fid)->output_body;
    REQUIRE(doc.body(mirrored) != nullptr);
    REQUIRE(shape::volume(doc.body(mirrored)->shape) == Approx(1000.0).epsilon(1e-6));
    REQUIRE(shape::center_of_mass(doc.body(mirrored)->shape)[0] == Approx(25.0).epsilon(1e-6));
    REQUIRE(doc.body(mirrored)->name == "Mirror of " + graph.feature(box_fid)->name);

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(mir_fid)->output_body == mirrored);
    REQUIRE(doc.body(mirrored) != nullptr);
    REQUIRE(doc.body_ids().size() == 2);

    // Parametric edit of source box: mirrored body id stays stable.
    json p = graph.feature(box_fid)->params;
    p["c"] = 20.0;
    REQUIRE(graph.set_params(box_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(mir_fid)->output_body == mirrored);
    REQUIRE(shape::volume(doc.body(mirrored)->shape) == Approx(2000.0).epsilon(1e-6));
}

TEST_CASE("featops: linear pattern count/spacing edits keep and drop body ids", "[featops]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature pat;
    pat.type = FeatureType::LinearPattern;
    pat.params = {{"target", box_fid.str()},
                  {"direction", json::array({1.0, 0.0, 0.0})},
                  {"spacing", 20.0},
                  {"count", 4}};
    auto pat_fid = graph.add(std::move(pat));
    REQUIRE(graph.feature(pat_fid)->output_body.is_null());
    REQUIRE(graph.feature(pat_fid)->output_bodies.empty());

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(pat_fid)->output_bodies.size() == 3);
    REQUIRE(doc.body_ids().size() == 4);

    auto copies = graph.feature(pat_fid)->output_bodies;
    std::vector<double> xs;
    xs.push_back(shape::center_of_mass(doc.body(graph.feature(box_fid)->output_body)->shape)[0]);
    for (const auto& id : copies) {
        REQUIRE(doc.body(id) != nullptr);
        REQUIRE(shape::volume(doc.body(id)->shape) == Approx(1000.0).epsilon(1e-6));
        xs.push_back(shape::center_of_mass(doc.body(id)->shape)[0]);
    }
    std::sort(xs.begin(), xs.end());
    REQUIRE(xs[0] == Approx(5.0).epsilon(1e-6));
    REQUIRE(xs[1] == Approx(25.0).epsilon(1e-6));
    REQUIRE(xs[2] == Approx(45.0).epsilon(1e-6));
    REQUIRE(xs[3] == Approx(65.0).epsilon(1e-6));

    // Edit spacing → same body ids.
    json p = graph.feature(pat_fid)->params;
    p["spacing"] = 30.0;
    REQUIRE(graph.set_params(pat_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(pat_fid)->output_bodies == copies);
    REQUIRE(shape::center_of_mass(doc.body(copies[0])->shape)[0] == Approx(35.0).epsilon(1e-6));

    // count 4→6: first three ids kept, two new appended.
    p = graph.feature(pat_fid)->params;
    p["count"] = 6;
    REQUIRE(graph.set_params(pat_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const auto& grown = graph.feature(pat_fid)->output_bodies;
    REQUIRE(grown.size() == 5);
    REQUIRE(grown[0] == copies[0]);
    REQUIRE(grown[1] == copies[1]);
    REQUIRE(grown[2] == copies[2]);
    REQUIRE(grown[3] != copies[0]);
    REQUIRE(grown[4] != copies[0]);
    REQUIRE(doc.body_ids().size() == 6);

    EntityId extra_a = grown[3];
    EntityId extra_b = grown[4];

    // count 6→3: survivors keep ids; extras removed from the document.
    p = graph.feature(pat_fid)->params;
    p["count"] = 3;
    REQUIRE(graph.set_params(pat_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    const auto& shrunk = graph.feature(pat_fid)->output_bodies;
    REQUIRE(shrunk.size() == 2);
    REQUIRE(shrunk[0] == copies[0]);
    REQUIRE(shrunk[1] == copies[1]);
    REQUIRE(doc.body(copies[2]) == nullptr);
    REQUIRE(doc.body(extra_a) == nullptr);
    REQUIRE(doc.body(extra_b) == nullptr);
    REQUIRE(doc.body_ids().size() == 3);
}

TEST_CASE("featops: circular pattern full circle", "[featops]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"},
                  {"a", 10.0},
                  {"b", 10.0},
                  {"c", 10.0},
                  {"origin", json::array({30.0, 0.0, 0.0})}};
    auto box_fid = graph.add(std::move(box));

    Feature pat;
    pat.type = FeatureType::CircularPattern;
    pat.params = {{"target", box_fid.str()},
                  {"axis_point", json::array({0.0, 0.0, 0.0})},
                  {"axis_dir", json::array({0.0, 0.0, 1.0})},
                  {"count", 6},
                  {"total_angle", 2.0 * M_PI}};
    auto pat_fid = graph.add(std::move(pat));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(graph.feature(pat_fid)->output_bodies.size() == 5);
    REQUIRE(doc.body_ids().size() == 6);

    std::vector<double> radii;
    radii.push_back(dist_from_z_axis(
        shape::center_of_mass(doc.body(graph.feature(box_fid)->output_body)->shape)));
    for (const auto& id : graph.feature(pat_fid)->output_bodies) {
        REQUIRE(shape::volume(doc.body(id)->shape) == Approx(1000.0).epsilon(1e-6));
        radii.push_back(dist_from_z_axis(shape::center_of_mass(doc.body(id)->shape)));
    }
    for (double r : radii) REQUIRE(r == Approx(radii[0]).epsilon(1e-6));
}

TEST_CASE("featops: shell modifies target in place", "[featops]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    int top = top_face_index(doc, body_id);

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.params = {{"target", box_fid.str()}, {"faces", json::array({top})}, {"thickness", 2.0}};
    auto sh_fid = graph.add(std::move(sh));
    REQUIRE(graph.feature(sh_fid)->output_body.is_null());

    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) != nullptr);
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(3392.0).epsilon(0.01));
    REQUIRE(doc.body_ids().size() == 1);

    json p = graph.feature(sh_fid)->params;
    p["thickness"] = 1.0;
    REQUIRE(graph.set_params(sh_fid, p));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(body_id) != nullptr);  // target id unchanged
    // outer 20^3 minus open cavity 18x18x19 = 8000 - 6156 = 1844
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(1844.0).epsilon(0.01));
}

TEST_CASE("featops: offset grows a box with arc joins", "[featops]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));

    Feature off;
    off.type = FeatureType::Offset;
    off.params = {{"target", box_fid.str()}, {"offset", 2.0}};
    auto off_fid = graph.add(std::move(off));
    REQUIRE(graph.feature(off_fid)->output_body.is_null());

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    EntityId body_id = graph.feature(box_fid)->output_body;
    const double expected =
        8000.0 + 6.0 * 400.0 * 2.0 + 12.0 * (M_PI * 4.0 / 4.0 * 20.0) + (4.0 / 3.0) * M_PI * 8.0;
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(expected).epsilon(0.01));
}

TEST_CASE("featops: removing a pattern removes its copies", "[featops]") {
    Document doc;
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box_fid = graph.add(std::move(box));

    Feature pat;
    pat.type = FeatureType::LinearPattern;
    pat.params = {{"target", box_fid.str()},
                  {"direction", json::array({0.0, 1.0, 0.0})},
                  {"spacing", 15.0},
                  {"count", 3}};
    auto pat_fid = graph.add(std::move(pat));

    std::string err;
    REQUIRE(graph.regenerate(doc, &err));
    auto copies = graph.feature(pat_fid)->output_bodies;
    REQUIRE(copies.size() == 2);
    REQUIRE(doc.body_ids().size() == 3);

    REQUIRE(graph.remove(pat_fid));
    REQUIRE(graph.regenerate(doc, &err));
    REQUIRE(doc.body(copies[0]) == nullptr);
    REQUIRE(doc.body(copies[1]) == nullptr);
    REQUIRE(doc.body_ids().size() == 1);
    REQUIRE(doc.body(graph.feature(box_fid)->output_body) != nullptr);
}

TEST_CASE("featops: json round-trip of all five new types", "[featops]") {
    FeatureGraph graph;

    Feature box;
    box.type = FeatureType::Primitive;
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 20.0}};
    auto box_fid = graph.add(std::move(box));

    Feature mir;
    mir.type = FeatureType::Mirror;
    mir.params = {{"target", box_fid.str()},
                  {"plane_point", json::array({0.0, 0.0, 0.0})},
                  {"plane_normal", json::array({1.0, 0.0, 0.0})}};
    auto mir_fid = graph.add(std::move(mir));

    Feature lin;
    lin.type = FeatureType::LinearPattern;
    lin.params = {{"target", box_fid.str()},
                  {"direction", json::array({1.0, 0.0, 0.0})},
                  {"spacing", 30.0},
                  {"count", 3}};
    auto lin_fid = graph.add(std::move(lin));

    Feature circ;
    circ.type = FeatureType::CircularPattern;
    circ.params = {{"target", box_fid.str()},
                   {"axis_point", json::array({0.0, 0.0, 0.0})},
                   {"axis_dir", json::array({0.0, 0.0, 1.0})},
                   {"count", 4},
                   {"total_angle", M_PI}};
    auto circ_fid = graph.add(std::move(circ));

    Feature sh;
    sh.type = FeatureType::Shell;
    sh.params = {{"target", box_fid.str()}, {"faces", json::array({6})}, {"thickness", 2.0}};
    auto sh_fid = graph.add(std::move(sh));

    Feature off;
    off.type = FeatureType::Offset;
    // Separate primitive so shell/offset don't fight over the same body in regen.
    Feature box2;
    box2.type = FeatureType::Primitive;
    box2.params = {{"kind", "box"}, {"a", 10.0}, {"b", 10.0}, {"c", 10.0}};
    auto box2_fid = graph.add(std::move(box2));
    off.params = {{"target", box2_fid.str()}, {"offset", 1.0}};
    auto off_fid = graph.add(std::move(off));

    Document doc;
    std::string err;
    REQUIRE(graph.regenerate(doc, &err));

    // Populate pattern output_bodies via regenerate before serializing.
    REQUIRE(graph.feature(lin_fid)->output_bodies.size() == 2);
    REQUIRE(graph.feature(circ_fid)->output_bodies.size() == 3);

    json j = graph.to_json();
    FeatureGraph restored = FeatureGraph::from_json(j);

    REQUIRE(restored.timeline().size() == graph.timeline().size());
    REQUIRE(restored.feature(mir_fid)->type == FeatureType::Mirror);
    REQUIRE(restored.feature(mir_fid)->params["target"] == box_fid.str());
    REQUIRE(restored.feature(mir_fid)->output_body == graph.feature(mir_fid)->output_body);

    REQUIRE(restored.feature(lin_fid)->type == FeatureType::LinearPattern);
    REQUIRE(restored.feature(lin_fid)->params["count"] == 3);
    REQUIRE(restored.feature(lin_fid)->output_bodies == graph.feature(lin_fid)->output_bodies);

    REQUIRE(restored.feature(circ_fid)->type == FeatureType::CircularPattern);
    REQUIRE(restored.feature(circ_fid)->output_bodies == graph.feature(circ_fid)->output_bodies);

    REQUIRE(restored.feature(sh_fid)->type == FeatureType::Shell);
    REQUIRE(restored.feature(sh_fid)->params["thickness"] == Approx(2.0));
    REQUIRE(restored.feature(sh_fid)->output_body.is_null());

    REQUIRE(restored.feature(off_fid)->type == FeatureType::Offset);
    REQUIRE(restored.feature(off_fid)->params["offset"] == Approx(1.0));
}
