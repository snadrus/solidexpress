#include "sx/entity.hpp"

#include <stdexcept>

namespace sx {

const char* to_string(EntityKind k) {
    switch (k) {
        case EntityKind::Body: return "body";
        case EntityKind::Face: return "face";
        case EntityKind::Edge: return "edge";
        case EntityKind::Vertex: return "vertex";
        case EntityKind::Sketch: return "sketch";
        case EntityKind::SketchEntity: return "sketch_entity";
        case EntityKind::SketchConstraint: return "sketch_constraint";
        case EntityKind::Feature: return "feature";
        case EntityKind::Component: return "component";
        case EntityKind::Joint: return "joint";
        case EntityKind::DrawingView: return "drawing_view";
        case EntityKind::DatumPlane: return "datum_plane";
        case EntityKind::DatumAxis: return "datum_axis";
        case EntityKind::DatumPoint: return "datum_point";
    }
    return "unknown";
}

EntityKind entity_kind_from_string(const std::string& s) {
    if (s == "body") return EntityKind::Body;
    if (s == "face") return EntityKind::Face;
    if (s == "edge") return EntityKind::Edge;
    if (s == "vertex") return EntityKind::Vertex;
    if (s == "sketch") return EntityKind::Sketch;
    if (s == "sketch_entity") return EntityKind::SketchEntity;
    if (s == "sketch_constraint") return EntityKind::SketchConstraint;
    if (s == "feature") return EntityKind::Feature;
    if (s == "component") return EntityKind::Component;
    if (s == "joint") return EntityKind::Joint;
    if (s == "drawing_view") return EntityKind::DrawingView;
    if (s == "datum_plane") return EntityKind::DatumPlane;
    if (s == "datum_axis") return EntityKind::DatumAxis;
    if (s == "datum_point") return EntityKind::DatumPoint;
    throw std::invalid_argument("unknown EntityKind: " + s);
}

}  // namespace sx
