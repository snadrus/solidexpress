#pragma once
// Own DXF R12 reader (LINE / CIRCLE / ARC / LWPOLYLINE). No libdxfrw.

#include <string>
#include <vector>

#include "sx/ids.hpp"
#include "sx/sketch.hpp"

namespace sx {

struct DxfEntity {
    enum class Kind { Line, Circle, Arc } kind = Kind::Line;
    double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
    double cx = 0, cy = 0, radius = 0;
    double start_angle = 0, end_angle = 0;  // degrees, ARC only
};

// Parse a text DXF. Returns empty + *err on I/O or empty ENTITIES.
std::vector<DxfEntity> read_dxf(const std::string& path, std::string* err = nullptr);

// Append parsed entities onto a sketch (model-space XY).
int add_dxf_to_sketch(Sketch& sketch, const std::vector<DxfEntity>& entities);

// Create a Sketch feature on the document graph from a DXF file.
EntityId import_dxf_sketch(class Document& doc, const std::string& path, std::string* err = nullptr);

}  // namespace sx
