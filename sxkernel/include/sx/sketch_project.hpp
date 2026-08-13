#pragma once
// Project model edges onto a sketch plane (SolidWorks Convert Entities).

#include <string>
#include <vector>

#include "sx/ids.hpp"
#include "sx/sketch.hpp"

namespace sx {

class Document;

// Project every edge of `face` onto the sketch plane and add LINE (or CIRCLE
// / ARC when the edge is circular and coplanar) entities. Edges whose
// endpoints project to the same UV within tolerance are skipped.
// Returns new sketch entity ids.
std::vector<std::string> convert_face_edges(Sketch& sketch, const Document& doc,
                                            const EntityId& face_id);

}  // namespace sx
