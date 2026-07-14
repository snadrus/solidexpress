#include <catch.hpp>
#include <cmath>

#include "sx/commands_sketch.hpp"
#include "sx/commands_sweep.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;

static std::shared_ptr<Sketch> rect_sketch(double w, double h, SketchPlane plane = {}) {
    auto sk = std::make_shared<Sketch>("Rect", plane);
    sk->add_line(0, 0, w, 0);
    sk->add_line(w, 0, w, h);
    sk->add_line(w, h, 0, h);
    sk->add_line(0, h, 0, 0);
    return sk;
}

static std::shared_ptr<Sketch> circle_sketch(double r, SketchPlane plane = {}) {
    auto sk = std::make_shared<Sketch>("Disk", plane);
    sk->add_circle(0, 0, r);
    return sk;
}

static double polyline_length(const std::vector<std::array<double, 3>>& pts) {
    double len = 0;
    for (size_t i = 1; i < pts.size(); ++i) {
        double dx = pts[i][0] - pts[i - 1][0];
        double dy = pts[i][1] - pts[i - 1][1];
        double dz = pts[i][2] - pts[i - 1][2];
        len += std::sqrt(dx * dx + dy * dy + dz * dz);
    }
    return len;
}

TEST_CASE("sweep circle along L-path produces valid solid", "[sweep]") {
    Document doc;
    CommandStack stack;
    const double r = 2.0;
    auto sk = circle_sketch(r);

    // L-shaped path in the YZ / XY sense: up Z then along X.
    std::vector<std::array<double, 3>> path{{0, 0, 0}, {0, 0, 40}, {30, 0, 40}};
    const double path_len = polyline_length(path);
    const double area = M_PI * r * r;
    const double expected = area * path_len;

    auto cmd = std::make_unique<SweepCommand>(sk, path);
    SweepCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    const Body* b = doc.body(raw->created_body());
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    REQUIRE(shape::count(b->shape).solids >= 1);
    REQUIRE(shape::volume(b->shape) == Approx(expected).epsilon(0.15));
}

TEST_CASE("sweep along straight path matches extrude volume", "[sweep]") {
    Document doc;
    CommandStack stack;
    auto sk = circle_sketch(5.0);
    const double height = 25.0;

    auto extrude = std::make_unique<ExtrudeCommand>(sk, height);
    ExtrudeCommand* ex = extrude.get();
    stack.push(doc, std::move(extrude));
    const double extrude_vol = shape::volume(doc.body(ex->created_body())->shape);

    auto sweep = std::make_unique<SweepCommand>(
        sk, std::vector<std::array<double, 3>>{{0, 0, 0}, {0, 0, height}});
    SweepCommand* sw = sweep.get();
    stack.push(doc, std::move(sweep));
    const double sweep_vol = shape::volume(doc.body(sw->created_body())->shape);

    REQUIRE(sweep_vol == Approx(extrude_vol).epsilon(1e-6));
}

TEST_CASE("loft square frustum volume", "[sweep]") {
    Document doc;
    CommandStack stack;

    auto bottom = rect_sketch(20, 20);
    SketchPlane top_plane;
    top_plane.origin = {0, 0, 30};
    auto top = rect_sketch(10, 10, top_plane);

    std::vector<std::shared_ptr<const Sketch>> profiles{bottom, top};
    auto cmd = std::make_unique<LoftCommand>(profiles, /*ruled=*/true);
    LoftCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    const Body* b = doc.body(raw->created_body());
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));

    const double A1 = 400.0;
    const double A2 = 100.0;
    const double h = 30.0;
    const double vol = shape::volume(b->shape);
    REQUIRE(vol > A2 * h);
    REQUIRE(vol < A1 * h);

    const double frustum = h / 3.0 * (A1 + A2 + std::sqrt(A1 * A2));
    REQUIRE(vol == Approx(frustum).epsilon(0.05));
}

TEST_CASE("loft with single profile throws", "[sweep]") {
    Document doc;
    auto sk = rect_sketch(10, 10);
    std::vector<std::shared_ptr<const Sketch>> profiles{sk};
    auto cmd = std::make_unique<LoftCommand>(profiles);
    REQUIRE_THROWS_AS(cmd->execute(doc), std::runtime_error);
}

TEST_CASE("sweep undo/redo preserves body EntityId", "[sweep]") {
    Document doc;
    CommandStack stack;
    auto sk = circle_sketch(3.0);

    auto cmd = std::make_unique<SweepCommand>(
        sk, std::vector<std::array<double, 3>>{{0, 0, 0}, {0, 0, 12}});
    SweepCommand* raw = cmd.get();
    stack.push(doc, std::move(cmd));

    EntityId id = raw->created_body();
    REQUIRE(doc.body(id) != nullptr);

    stack.undo(doc);
    REQUIRE(doc.body(id) == nullptr);
    REQUIRE(doc.body_ids().empty());

    stack.redo(doc);
    REQUIRE(doc.body(id) != nullptr);
    REQUIRE(doc.body(id)->id == id);
}

TEST_CASE("sweep open profile throws", "[sweep]") {
    Document doc;
    auto sk = std::make_shared<Sketch>("Open");
    sk->add_line(0, 0, 10, 0);
    auto cmd = std::make_unique<SweepCommand>(
        sk, std::vector<std::array<double, 3>>{{0, 0, 0}, {0, 0, 5}});
    REQUIRE_THROWS_AS(cmd->execute(doc), std::runtime_error);
}
