#pragma once
#include <string>

#include "sx/ids.hpp"

namespace sx {

enum class EntityKind {
    Body,
    Face,
    Edge,
    Vertex,
    Sketch,
    SketchEntity,
    SketchConstraint,
    Feature,
    Component,
    Joint,
    DrawingView,
    DatumPlane,
    DatumAxis,
    DatumPoint,
};

const char* to_string(EntityKind k);
EntityKind entity_kind_from_string(const std::string& s);

}  // namespace sx
