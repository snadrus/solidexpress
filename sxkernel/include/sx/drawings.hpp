#pragma once
// Drawings MVP: hidden-line-removed 2D projections of bodies and an SVG
// sheet writer. Views are computed with OCCT's HLR algorithm and returned
// as 2D polylines in view coordinates (mm, y-up), ready for layout.

#include <array>
#include <string>
#include <vector>

#include <TopoDS_Shape.hxx>
#include <gp_Dir.hxx>

namespace sx {
class Document;
}

namespace sx::drawings {

using Point2 = std::array<double, 2>;
using Polyline2 = std::vector<Point2>;

struct ViewProjection {
    std::vector<Polyline2> visible;  // sharp edges + silhouette outlines
    std::vector<Polyline2> hidden;   // hidden-line edges (drawn dashed)
    // 2D bounds across both edge sets; zero-size when empty.
    double min_x = 0, min_y = 0, max_x = 0, max_y = 0;
};

// Projects `shape` along `view_dir` (viewer looks down this direction) with
// `up` as the sheet's +Y. Polylines come back in the projection plane's
// coordinates.
ViewProjection project(const TopoDS_Shape& shape, const gp_Dir& view_dir, const gp_Dir& up);

// A placed view on a sheet: projection plus the sheet-space offset of its
// lower-left corner.
struct PlacedView {
    ViewProjection view;
    std::string label;
    double offset_x = 0;
    double offset_y = 0;
};

// Writes an SVG sheet (mm units, y flipped into SVG's y-down space).
// Visible edges solid, hidden edges dashed. Returns false on I/O failure.
bool write_svg(const std::vector<PlacedView>& views, const std::string& path,
               double scale = 1.0, double margin = 10.0);

// Convenience: third-angle front/top/right sheet of every body in the
// document (kernel frame: front looks along +Y, top looks along -Z).
bool export_three_view_svg(const Document& doc, const std::string& path,
                           double scale = 1.0);

}  // namespace sx::drawings
