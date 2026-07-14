#pragma once
// Lightweight component instances: a placement of a source body under a
// rigid transform. Assembly groundwork — instances share geometry with the
// source and do not own topology.

#include <array>
#include <string>

#include <TopoDS_Shape.hxx>
#include <gp_Trsf.hxx>
#include <nlohmann/json.hpp>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct Instance {
    EntityId id;
    EntityId source_body;
    std::array<double, 3> translation{0, 0, 0};
    // Unit quaternion as (x, y, z, w). Identity is (0, 0, 0, 1).
    std::array<double, 4> rotation_quat{0, 0, 0, 1};
    std::string name;
};

void to_json(nlohmann::json& j, const Instance& inst);
void from_json(const nlohmann::json& j, Instance& inst);

gp_Trsf transform_of(const Instance& inst);

// Source body's shape with the instance transform applied (location only;
// cheap TopoDS_Shape::Moved — no BRep copy).
TopoDS_Shape resolved_shape(const Document& doc, const Instance& inst);

}  // namespace sx
