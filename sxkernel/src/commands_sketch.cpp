#include "sx/commands_sketch.hpp"

#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <gp_Ax1.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <stdexcept>

#include "sx/document.hpp"

namespace sx {

namespace {
int feature_counter = 0;

std::shared_ptr<void> snapshot(const Body& b) { return std::make_shared<Body>(b); }
const Body& snap(const std::shared_ptr<void>& p) {
    return *static_cast<const Body*>(p.get());
}
}  // namespace

ExtrudeCommand::ExtrudeCommand(std::shared_ptr<const Sketch> sketch, double distance,
                               bool symmetric, std::string name)
    : sketch_(std::move(sketch)), distance_(distance), symmetric_(symmetric),
      name_(std::move(name)) {
    if (name_.empty()) name_ = "Pad " + std::to_string(++feature_counter);
}

void ExtrudeCommand::execute(Document& doc) {
    std::string err;
    TopoDS_Shape face = sketch_->profile_face(&err);
    if (face.IsNull()) throw std::runtime_error("Extrude: " + err);

    auto n = sketch_->plane().normal();
    gp_Vec dir(n[0], n[1], n[2]);
    dir.Normalize();

    TopoDS_Shape profile = face;
    double dist = distance_;
    if (symmetric_) {
        // Shift the profile back half the distance, then extrude the full way.
        gp_Trsf t;
        t.SetTranslation(dir * (-dist / 2.0));
        profile = BRepBuilderAPI_Transform(face, t, true).Shape();
    }
    TopoDS_Shape solid = BRepPrimAPI_MakePrism(profile, dir * dist).Shape();
    if (solid.IsNull()) throw std::runtime_error("Extrude: prism failed");

    body_ = doc.add_body(solid, name_);
    saved_ = snapshot(*doc.body(body_));
}

void ExtrudeCommand::undo(Document& doc) { doc.remove_body(body_); }

void ExtrudeCommand::redo(Document& doc) {
    Body copy = snap(saved_);
    doc.restore_body(std::move(copy));
}

RevolveCommand::RevolveCommand(std::shared_ptr<const Sketch> sketch,
                               std::array<double, 2> axis_point,
                               std::array<double, 2> axis_dir, double angle,
                               std::string name)
    : sketch_(std::move(sketch)), axis_point_(axis_point), axis_dir_(axis_dir),
      angle_(angle), name_(std::move(name)) {
    if (name_.empty()) name_ = "Revolve " + std::to_string(++feature_counter);
}

void RevolveCommand::execute(Document& doc) {
    std::string err;
    TopoDS_Shape face = sketch_->profile_face(&err);
    if (face.IsNull()) throw std::runtime_error("Revolve: " + err);

    const auto& pl = sketch_->plane();
    auto at = [&](double u, double v) {
        return gp_Pnt(pl.origin[0] + pl.x_dir[0] * u + pl.y_dir[0] * v,
                      pl.origin[1] + pl.x_dir[1] * u + pl.y_dir[1] * v,
                      pl.origin[2] + pl.x_dir[2] * u + pl.y_dir[2] * v);
    };
    gp_Pnt p0 = at(axis_point_[0], axis_point_[1]);
    gp_Pnt p1 = at(axis_point_[0] + axis_dir_[0], axis_point_[1] + axis_dir_[1]);
    gp_Ax1 axis(p0, gp_Dir(gp_Vec(p0, p1)));

    TopoDS_Shape solid = BRepPrimAPI_MakeRevol(face, axis, angle_).Shape();
    if (solid.IsNull()) throw std::runtime_error("Revolve: revol failed");

    body_ = doc.add_body(solid, name_);
    saved_ = snapshot(*doc.body(body_));
}

void RevolveCommand::undo(Document& doc) { doc.remove_body(body_); }

void RevolveCommand::redo(Document& doc) {
    Body copy = snap(saved_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
