#pragma once
// Datum / reference geometry: planes, axes, and points used as construction
// references (standard planes, face-derived planes, cylinder axes, etc.).

#include <array>
#include <string>

#include <TopoDS_Shape.hxx>
#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

struct DatumPlane {
    EntityId id;
    std::string name;
    std::array<double, 3> origin{0, 0, 0};
    std::array<double, 3> normal{0, 0, 1};
    std::array<double, 3> x_dir{1, 0, 0};

    // Right-handed Y: normalize(normal × x_dir).
    std::array<double, 3> y_dir() const;
};

struct DatumAxis {
    EntityId id;
    std::string name;
    std::array<double, 3> point{0, 0, 0};
    std::array<double, 3> direction{0, 0, 1};
};

struct DatumPoint {
    EntityId id;
    std::string name;
    std::array<double, 3> position{0, 0, 0};
};

void to_json(nlohmann::json& j, const DatumPlane& p);
void from_json(const nlohmann::json& j, DatumPlane& p);
void to_json(nlohmann::json& j, const DatumAxis& a);
void from_json(const nlohmann::json& j, DatumAxis& a);
void to_json(nlohmann::json& j, const DatumPoint& p);
void from_json(const nlohmann::json& j, DatumPoint& p);

namespace datum {

// Standard origin planes named "XY" / "XZ" / "YZ".
DatumPlane plane_xy(const EntityId& keep_id = {});
DatumPlane plane_xz(const EntityId& keep_id = {});
DatumPlane plane_yz(const EntityId& keep_id = {});

// Parallel plane offset along the source normal by `distance`.
DatumPlane plane_offset(const DatumPlane& src, double distance,
                        const EntityId& keep_id = {});

// Extract a datum plane from a planar TopoDS_Face. Throws std::runtime_error
// if the face is not planar. Origin is the UV-midpoint mapped to 3D; x_dir is
// the underlying Geom_Plane / fitted plane local X axis.
DatumPlane plane_from_face(const TopoDS_Shape& face, const EntityId& keep_id = {});

// Plane through three non-collinear points; x_dir along p1→p2. Throws if
// the points are (nearly) collinear.
DatumPlane plane_from_points(const std::array<double, 3>& p1,
                             const std::array<double, 3>& p2,
                             const std::array<double, 3>& p3,
                             const EntityId& keep_id = {});

// Axis through two distinct points; direction p1→p2. Throws if coincident.
DatumAxis axis_from_points(const std::array<double, 3>& p1,
                           const std::array<double, 3>& p2,
                           const EntityId& keep_id = {});

// Axis of a cylindrical face. Throws if the face is not a cylinder.
DatumAxis axis_of_cylinder(const TopoDS_Shape& face, const EntityId& keep_id = {});

// Angle between plane normals in radians, in [0, π].
double angle_between(const DatumPlane& a, const DatumPlane& b);

}  // namespace datum
}  // namespace sx
