#include "sx/commands_hole.hpp"

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <gp_Vec.hxx>

#include <cmath>

#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

namespace sx {

namespace {
std::shared_ptr<void> snapshot(const Body& b) {
    return std::make_shared<Body>(b);
}
const Body& snap(const std::shared_ptr<void>& p) {
    return *static_cast<const Body*>(p.get());
}

constexpr double k_nudge = 1.0;  // start tool above entry to avoid coincident-face booleans
constexpr double k_through = 1e6;

shape::Placement ax_placement(const gp_Pnt& origin, const gp_Dir& z) {
    shape::Placement p;
    p.origin = {origin.X(), origin.Y(), origin.Z()};
    p.z_dir = {z.X(), z.Y(), z.Z()};
    const gp_Dir ref = (std::abs(z.Dot(gp_Dir(0, 0, 1))) < 0.9) ? gp_Dir(0, 0, 1)
                                                                  : gp_Dir(1, 0, 0);
    const gp_Dir x = z.Crossed(ref);
    p.x_dir = {x.X(), x.Y(), x.Z()};
    return p;
}

TopoDS_Shape build_hole_tool(const gp_Pnt& position, const gp_Dir& direction,
                             double diameter, double depth, HoleType type,
                             double secondary_diameter, double secondary_param) {
    const double radius = diameter * 0.5;
    if (radius <= 0.0 || depth <= 0.0) return {};

    // Nudge origin slightly above the entry surface along -direction.
    const gp_Pnt origin = position.Translated(gp_Vec(direction) * (-k_nudge));
    const double cyl_h = depth + k_nudge;
    const auto place = ax_placement(origin, direction);

    TopoDS_Shape tool = shape::make_cylinder(radius, cyl_h, place);
    if (tool.IsNull()) return {};

    if (type == HoleType::Simple) return tool;

    if (type == HoleType::Counterbore) {
        const double cb_r = secondary_diameter * 0.5;
        const double cb_depth = secondary_param;
        if (cb_r <= radius || cb_depth <= 0.0) return {};
        TopoDS_Shape cb = shape::make_cylinder(cb_r, cb_depth + k_nudge, place);
        BRepAlgoAPI_Fuse fuse(tool, cb);
        if (!fuse.IsDone()) return {};
        return fuse.Shape();
    }

    // Countersink: cone from CS radius at the nudged origin, tapering over
    // (cs_h + nudge) so the wide mouth covers the entry surface.
    const double cs_r = secondary_diameter * 0.5;
    const double angle = secondary_param;  // included angle, radians
    if (cs_r <= radius || angle <= 0.0 || angle >= M_PI) return {};
    const double half = angle * 0.5;
    const double tan_half = std::tan(half);
    if (tan_half <= 1e-12) return {};
    const double cs_h = (cs_r - radius) / tan_half;
    if (cs_h <= 0.0) return {};

    const double cone_h = cs_h + k_nudge;
    const double r2 = std::max(0.0, cs_r - cone_h * tan_half);
    TopoDS_Shape cone = shape::make_cone(cs_r, r2, cone_h, place);
    BRepAlgoAPI_Fuse fuse(tool, cone);
    if (!fuse.IsDone()) return {};
    return fuse.Shape();
}

}  // namespace

bool HoleCommand::try_execute(Document& doc) {
    if (body_.is_null() || diameter_ <= 0.0) return false;

    const Body* b = doc.body(body_);
    if (!b) return false;

    const double depth = depth_ > 0.0 ? depth_ : k_through;
    TopoDS_Shape tool = build_hole_tool(position_, direction_, diameter_, depth, type_,
                                        secondary_diameter_, secondary_param_);
    if (tool.IsNull() || !shape::is_valid(tool)) return false;

    saved_before_ = snapshot(*b);

    BRepAlgoAPI_Cut cut(b->shape, tool);
    if (!cut.IsDone()) {
        saved_before_.reset();
        return false;
    }

    TopoDS_Shape result = cut.Shape();
    if (result.IsNull() || !shape::is_valid(result)) {
        saved_before_.reset();
        return false;
    }
    if (shape::count(result).solids < 1 || shape::volume(result) <= 0.0) {
        saved_before_.reset();
        return false;
    }

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
    return true;
}

void HoleCommand::execute(Document& doc) { (void)try_execute(doc); }

void HoleCommand::undo(Document& doc) {
    if (!saved_before_) return;
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void HoleCommand::redo(Document& doc) {
    if (!saved_after_) return;
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
