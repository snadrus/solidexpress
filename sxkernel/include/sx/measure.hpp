#pragma once
// Geometric measurements over Document entities: distance, bbox, mass props,
// edge/face metrics, and planar-face angles. Used by the Measure UI and cards.

#include <array>
#include <optional>

#include "sx/document.hpp"
#include "sx/ids.hpp"

namespace sx::measure {

struct DistanceResult {
    double distance = 0.0;
    std::array<double, 3> point_a{};
    std::array<double, 3> point_b{};
};

// Minimum distance between two resolved shapes (body or subshape ids).
std::optional<DistanceResult> min_distance(const Document& doc, const EntityId& a,
                                           const EntityId& b);

struct BBox {
    std::array<double, 3> min{};
    std::array<double, 3> max{};
};

std::optional<BBox> bounding_box(const Document& doc, const EntityId& id);

struct MassProps {
    double volume = 0.0;
    double surface_area = 0.0;
    std::array<double, 3> center_of_mass{};
    // 3x3 inertia matrix about the center of mass, row-major.
    std::array<double, 9> inertia{};
};

// Volume properties for a body id only.
std::optional<MassProps> mass_properties(const Document& doc, const EntityId& body);

double edge_length(const Document& doc, const EntityId& edge);
double face_area(const Document& doc, const EntityId& face);

// Angle between outward normals of two planar faces, in radians [0, pi].
std::optional<double> angle_between_faces(const Document& doc, const EntityId& f1,
                                          const EntityId& f2);

}  // namespace sx::measure
