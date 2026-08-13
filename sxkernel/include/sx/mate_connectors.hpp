#pragma once
// Implicit mate connectors (Onshape/Fusion style): local frames derived from
// planar face centers and cylindrical face axes. Used for magnetic snap while
// dragging instances — one connector→connector mate replaces several classic
// constraints.

#include <optional>
#include <string>
#include <vector>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include "sx/ids.hpp"
#include "sx/mates.hpp"

namespace sx {

class Document;

enum class ConnectorKind { Planar, Cylindrical };

struct MateConnector {
    EntityId face;
    EntityId instance;  // null => grounded body face
    EntityId body;      // source body owning the face
    ConnectorKind kind = ConnectorKind::Planar;
    gp_Pnt origin;
    gp_Dir z_axis;  // face normal or cylinder axis
    double radius = 0.0;  // cylindrical only
};

// All implicit connectors on grounded bodies and placed instances.
std::vector<MateConnector> implicit_connectors(const Document& doc);

struct ConnectorSnap {
    MateConnector from;  // on the moving instance
    MateConnector to;    // target (ground or other instance)
    MateType mate_type = MateType::PlaneCoincident;
    double distance = 0.0;
};

// Nearest compatible connector pair for `moving_instance` within max_dist (mm).
// Planar↔planar → PlaneCoincident; cylindrical↔cylindrical → Concentric.
std::optional<ConnectorSnap> find_connector_snap(const Document& doc,
                                                 const EntityId& moving_instance,
                                                 double max_dist = 8.0);

// Adds the suggested mate and runs solve_mates. Returns the new mate id, or
// null on failure.
EntityId apply_connector_snap(Document& doc, const ConnectorSnap& snap);

}  // namespace sx
