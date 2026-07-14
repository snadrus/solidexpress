#pragma once
// Pure 2D sketch geometry tools (fillet, offset). No OCCT dependency.

#include <string>
#include <vector>

#include "sx/sketch.hpp"

namespace sx::sketch_tools {

// Trim two lines that share a corner and insert a tangent fillet arc.
// Returns the new arc entity id, or "" on failure.
std::string fillet_corner(Sketch& s, const std::string& line_a_id,
                          const std::string& line_b_id, double radius);

// Offset each entity by signed distance. Lines get a parallel copy (positive =
// left of direction); circles change radius. Unsupported kinds are skipped.
// Returns new entity ids in input order (omitting skips).
std::vector<std::string> offset_entities(Sketch& s,
                                         const std::vector<std::string>& entity_ids,
                                         double distance);

}  // namespace sx::sketch_tools
