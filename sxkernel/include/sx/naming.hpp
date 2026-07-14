#pragma once
// Topological naming service (plan task 3.2). When a body's shape is
// rebuilt (modeling op or feature regeneration), subshape EntityIds must
// survive for the faces/edges/vertices that geometrically persist so that
// selections, semantic cards (user aliases/notes), and feature references
// stay valid.
//
// Strategy: signature matching. Each subshape gets a signature (geometry
// type, centroid, size, characteristic direction). Old and new subshapes of
// the same kind are paired greedily by ascending match cost; pairs above a
// cost threshold are rejected. Exact survivors match at cost ~0; modified
// survivors (a face that grew or moved slightly) match in the same pass at
// a small cost. Genuinely new subshapes get fresh ids; ids of vanished
// subshapes are reported so callers can retire their cards.

#include <TopoDS_Shape.hxx>

#include <array>
#include <map>
#include <vector>

#include "sx/entity.hpp"
#include "sx/ids.hpp"

namespace sx::naming {

struct Signature {
    int geom_type = -1;                       // GeomAbs_SurfaceType / CurveType, -1 vertex
    std::array<double, 3> center{0, 0, 0};    // centroid (face/edge) or position (vertex)
    double size = 0.0;                        // area (face), length (edge), 0 (vertex)
    std::array<double, 3> dir{0, 0, 0};       // plane normal / cylinder axis / line dir;
                                              // zero when not meaningful
};

// Signatures for all subshapes of `kind` in TopExp::MapShapes order (1-based
// map index i corresponds to element i-1).
std::vector<Signature> signatures(const TopoDS_Shape& shape, EntityKind kind);

struct MatchResult {
    // Ids for the new shape's subshapes in map order: survivors keep their
    // old id, newcomers get fresh ids.
    std::map<EntityKind, std::vector<EntityId>> ids;
    // Old ids with no surviving counterpart (their cards should be retired).
    std::vector<EntityId> released;
};

// Matches faces/edges/vertices of `new_shape` against `old_shape` whose ids
// are given in `old_ids` (map order per kind, as stored in Body::subshape_ids).
MatchResult match_subshapes(const TopoDS_Shape& old_shape,
                            const std::map<EntityKind, std::vector<EntityId>>& old_ids,
                            const TopoDS_Shape& new_shape);

}  // namespace sx::naming
