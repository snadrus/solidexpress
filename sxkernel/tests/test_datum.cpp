#include <catch.hpp>

#include <cmath>

#include <BRepAdaptor_Surface.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <nlohmann/json.hpp>

#include "sx/datum.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;
using nlohmann::json;

namespace {

bool approx_vec(const std::array<double, 3>& a, const std::array<double, 3>& b,
                double eps = 1e-9) {
    return std::abs(a[0] - b[0]) < eps && std::abs(a[1] - b[1]) < eps &&
           std::abs(a[2] - b[2]) < eps;
}

double vec_len(const std::array<double, 3>& v) {
    return std::sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

double dot(const std::array<double, 3>& a, const std::array<double, 3>& b) {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

}  // namespace

TEST_CASE("standard planes are orthonormal and named", "[datum]") {
    auto xy = datum::plane_xy();
    auto xz = datum::plane_xz();
    auto yz = datum::plane_yz();

    REQUIRE(xy.name == "XY");
    REQUIRE(xz.name == "XZ");
    REQUIRE(yz.name == "YZ");
    REQUIRE(!xy.id.is_null());
    REQUIRE(!xz.id.is_null());
    REQUIRE(!yz.id.is_null());
    REQUIRE(xy.id != xz.id);

    REQUIRE(approx_vec(xy.origin, {0, 0, 0}));
    REQUIRE(approx_vec(xy.normal, {0, 0, 1}));
    REQUIRE(approx_vec(xy.x_dir, {1, 0, 0}));
    REQUIRE(approx_vec(xy.y_dir(), {0, 1, 0}));

    REQUIRE(approx_vec(xz.normal, {0, 1, 0}));
    REQUIRE(approx_vec(xz.x_dir, {1, 0, 0}));
    REQUIRE(approx_vec(xz.y_dir(), {0, 0, -1}));

    REQUIRE(approx_vec(yz.normal, {1, 0, 0}));
    REQUIRE(approx_vec(yz.x_dir, {0, 1, 0}));
    REQUIRE(approx_vec(yz.y_dir(), {0, 0, 1}));

    for (const auto& p : {xy, xz, yz}) {
        REQUIRE(vec_len(p.normal) == Approx(1.0).epsilon(1e-12));
        REQUIRE(vec_len(p.x_dir) == Approx(1.0).epsilon(1e-12));
        REQUIRE(vec_len(p.y_dir()) == Approx(1.0).epsilon(1e-12));
        REQUIRE(std::abs(dot(p.normal, p.x_dir)) < 1e-12);
        REQUIRE(std::abs(dot(p.normal, p.y_dir())) < 1e-12);
        REQUIRE(std::abs(dot(p.x_dir, p.y_dir())) < 1e-12);
        // Right-handed: x × y ≈ normal
        auto y = p.y_dir();
        std::array<double, 3> cross = {p.x_dir[1] * y[2] - p.x_dir[2] * y[1],
                                       p.x_dir[2] * y[0] - p.x_dir[0] * y[2],
                                       p.x_dir[0] * y[1] - p.x_dir[1] * y[0]};
        REQUIRE(approx_vec(cross, p.normal));
    }
}

TEST_CASE("plane_offset moves origin along normal", "[datum]") {
    auto xy = datum::plane_xy();
    auto off = datum::plane_offset(xy, 5.0);
    REQUIRE(approx_vec(off.normal, xy.normal));
    REQUIRE(approx_vec(off.x_dir, xy.x_dir));
    REQUIRE(approx_vec(off.origin, {0, 0, 5}));
    REQUIRE(off.id != xy.id);

    auto back = datum::plane_offset(off, -5.0);
    REQUIRE(approx_vec(back.origin, {0, 0, 0}));
}

TEST_CASE("plane_from_face on box top face", "[datum]") {
    auto box = shape::make_box(10, 20, 30);
    REQUIRE(shape::is_valid(box));

    bool found = false;
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next()) {
        const TopoDS_Face f = TopoDS::Face(ex.Current());
        BRepAdaptor_Surface surf(f);
        if (surf.GetType() != GeomAbs_Plane) continue;
        gp_Dir n = surf.Plane().Axis().Direction();
        if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
        if (std::abs(n.Z() - 1.0) > 1e-9) continue;

        auto plane = datum::plane_from_face(f);
        REQUIRE(approx_vec(plane.normal, {0, 0, 1}));
        // UV midpoint of the top face of a default-placement box.
        REQUIRE(plane.origin[0] == Approx(5.0).epsilon(1e-9));
        REQUIRE(plane.origin[1] == Approx(10.0).epsilon(1e-9));
        REQUIRE(plane.origin[2] == Approx(30.0).epsilon(1e-9));
        REQUIRE(vec_len(plane.x_dir) == Approx(1.0).epsilon(1e-12));
        REQUIRE(std::abs(dot(plane.normal, plane.x_dir)) < 1e-12);
        found = true;
        break;
    }
    REQUIRE(found);
}

TEST_CASE("plane_from_points and collinear throw", "[datum]") {
    auto p = datum::plane_from_points({0, 0, 0}, {1, 0, 0}, {0, 1, 0});
    REQUIRE(approx_vec(p.origin, {0, 0, 0}));
    REQUIRE(approx_vec(p.x_dir, {1, 0, 0}));
    REQUIRE(approx_vec(p.normal, {0, 0, 1}));
    REQUIRE(approx_vec(p.y_dir(), {0, 1, 0}));

    REQUIRE_THROWS_AS(datum::plane_from_points({0, 0, 0}, {1, 0, 0}, {2, 0, 0}),
                      std::runtime_error);
}

TEST_CASE("axis_of_cylinder from cylinder side face", "[datum]") {
    auto cyl = shape::make_cylinder(5, 10);
    bool found = false;
    for (TopExp_Explorer ex(cyl, TopAbs_FACE); ex.More(); ex.Next()) {
        try {
            auto ax = datum::axis_of_cylinder(ex.Current());
            REQUIRE(std::abs(ax.direction[0]) < 1e-9);
            REQUIRE(std::abs(ax.direction[1]) < 1e-9);
            REQUIRE(std::abs(std::abs(ax.direction[2]) - 1.0) < 1e-9);
            REQUIRE(std::abs(ax.point[0]) < 1e-9);
            REQUIRE(std::abs(ax.point[1]) < 1e-9);
            found = true;
            break;
        } catch (const std::runtime_error&) {
            continue;
        }
    }
    REQUIRE(found);

    REQUIRE_THROWS_AS(datum::axis_from_points({1, 2, 3}, {1, 2, 3}), std::runtime_error);
    auto line = datum::axis_from_points({0, 0, 0}, {0, 0, 2});
    REQUIRE(approx_vec(line.point, {0, 0, 0}));
    REQUIRE(approx_vec(line.direction, {0, 0, 1}));
}

TEST_CASE("angle_between XY and XZ is pi/2", "[datum]") {
    auto xy = datum::plane_xy();
    auto xz = datum::plane_xz();
    REQUIRE(datum::angle_between(xy, xz) == Approx(M_PI / 2.0).epsilon(1e-12));
    REQUIRE(datum::angle_between(xy, xy) == Approx(0.0).margin(1e-12));
}

TEST_CASE("JSON round-trip for datum types", "[datum]") {
    auto plane = datum::plane_xy();
    plane.name = "MyXY";
    json jp = plane;
    DatumPlane plane2 = jp.get<DatumPlane>();
    REQUIRE(plane2.id == plane.id);
    REQUIRE(plane2.name == "MyXY");
    REQUIRE(approx_vec(plane2.origin, plane.origin));
    REQUIRE(approx_vec(plane2.normal, plane.normal));
    REQUIRE(approx_vec(plane2.x_dir, plane.x_dir));

    auto axis = datum::axis_from_points({1, 2, 3}, {4, 5, 6});
    axis.name = "Diag";
    json ja = axis;
    DatumAxis axis2 = ja.get<DatumAxis>();
    REQUIRE(axis2.id == axis.id);
    REQUIRE(axis2.name == "Diag");
    REQUIRE(approx_vec(axis2.point, axis.point));
    REQUIRE(approx_vec(axis2.direction, axis.direction));

    DatumPoint pt;
    pt.id = EntityId::generate();
    pt.name = "Origin";
    pt.position = {7, 8, 9};
    json jpt = pt;
    DatumPoint pt2 = jpt.get<DatumPoint>();
    REQUIRE(pt2.id == pt.id);
    REQUIRE(pt2.name == "Origin");
    REQUIRE(approx_vec(pt2.position, {7, 8, 9}));
}
