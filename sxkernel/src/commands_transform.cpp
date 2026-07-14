#include "sx/commands_transform.hpp"

#include <BRepBuilderAPI_Transform.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <stdexcept>

#include "sx/document.hpp"

namespace sx {

namespace {
std::shared_ptr<void> snapshot(const Body& b) {
    return std::make_shared<Body>(b);
}
const Body& snap(const std::shared_ptr<void>& p) {
    return *static_cast<const Body*>(p.get());
}

gp_Dir make_dir(const std::array<double, 3>& v) {
    const double len = std::sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (len < 1e-15) throw std::invalid_argument("zero-length direction");
    return gp_Dir(v[0] / len, v[1] / len, v[2] / len);
}

gp_Pnt make_pnt(const std::array<double, 3>& p) {
    return gp_Pnt(p[0], p[1], p[2]);
}
}  // namespace

// --- MirrorBodyCommand ---

void MirrorBodyCommand::execute(Document& doc) {
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("MirrorBodyCommand: no such body");

    gp_Trsf t;
    t.SetMirror(gp_Ax2(make_pnt(plane_point_), make_dir(plane_normal_)));
    BRepBuilderAPI_Transform xform(b->shape, t, /*copy=*/true);
    TopoDS_Shape mirrored = xform.Shape();

    const std::string name = "Mirror of " + b->name;
    if (!keep_original_) {
        saved_original_ = snapshot(*b);
        doc.remove_body(body_);
    }
    created_ = doc.add_body(mirrored, name);
    saved_created_ = snapshot(*doc.body(created_));
}

void MirrorBodyCommand::undo(Document& doc) {
    if (doc.body(created_)) doc.remove_body(created_);
    if (!keep_original_ && saved_original_) {
        Body copy = snap(saved_original_);
        doc.restore_body(std::move(copy));
    }
}

void MirrorBodyCommand::redo(Document& doc) {
    if (!keep_original_ && doc.body(body_)) doc.remove_body(body_);
    if (doc.body(created_)) doc.remove_body(created_);
    Body copy = snap(saved_created_);
    doc.restore_body(std::move(copy));
}

// --- LinearPatternCommand ---

void LinearPatternCommand::execute(Document& doc) {
    if (count_ < 2)
        throw std::invalid_argument("LinearPatternCommand: count must be >= 2");
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("LinearPatternCommand: no such body");

    gp_Dir dir = make_dir(direction_);
    created_.clear();
    saved_created_.clear();
    created_.reserve(static_cast<size_t>(count_ - 1));
    saved_created_.reserve(static_cast<size_t>(count_ - 1));

    for (int i = 1; i < count_; ++i) {
        gp_Trsf t;
        t.SetTranslation(gp_Vec(dir.XYZ() * (spacing_ * i)));
        BRepBuilderAPI_Transform xform(b->shape, t, /*copy=*/true);
        const std::string name = b->name + " [" + std::to_string(i + 1) + "]";
        EntityId id = doc.add_body(xform.Shape(), name);
        created_.push_back(id);
        saved_created_.push_back(snapshot(*doc.body(id)));
    }
}

void LinearPatternCommand::undo(Document& doc) {
    for (const auto& id : created_) {
        if (doc.body(id)) doc.remove_body(id);
    }
}

void LinearPatternCommand::redo(Document& doc) {
    for (const auto& id : created_) {
        if (doc.body(id)) doc.remove_body(id);
    }
    for (const auto& s : saved_created_) {
        Body copy = snap(s);
        doc.restore_body(std::move(copy));
    }
}

// --- CircularPatternCommand ---

void CircularPatternCommand::execute(Document& doc) {
    if (count_ < 2)
        throw std::invalid_argument("CircularPatternCommand: count must be >= 2");
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("CircularPatternCommand: no such body");

    gp_Ax1 axis(make_pnt(axis_point_), make_dir(axis_dir_));
    const double step = total_angle_ / static_cast<double>(count_);
    created_.clear();
    saved_created_.clear();
    created_.reserve(static_cast<size_t>(count_ - 1));
    saved_created_.reserve(static_cast<size_t>(count_ - 1));

    for (int i = 1; i < count_; ++i) {
        gp_Trsf t;
        t.SetRotation(axis, step * i);
        BRepBuilderAPI_Transform xform(b->shape, t, /*copy=*/true);
        const std::string name = b->name + " [" + std::to_string(i + 1) + "]";
        EntityId id = doc.add_body(xform.Shape(), name);
        created_.push_back(id);
        saved_created_.push_back(snapshot(*doc.body(id)));
    }
}

void CircularPatternCommand::undo(Document& doc) {
    for (const auto& id : created_) {
        if (doc.body(id)) doc.remove_body(id);
    }
}

void CircularPatternCommand::redo(Document& doc) {
    for (const auto& id : created_) {
        if (doc.body(id)) doc.remove_body(id);
    }
    for (const auto& s : saved_created_) {
        Body copy = snap(s);
        doc.restore_body(std::move(copy));
    }
}

// --- RotateBodyCommand ---

void RotateBodyCommand::apply(Document& doc, double angle) {
    Body* b = doc.body_mut(body_);
    if (!b) throw std::invalid_argument("RotateBodyCommand: no such body");
    gp_Trsf t;
    t.SetRotation(gp_Ax1(make_pnt(axis_point_), make_dir(axis_dir_)), angle);
    BRepBuilderAPI_Transform xform(b->shape, t, /*copy=*/false);
    b->shape = xform.Shape();
    doc.bump_revision();
}

void RotateBodyCommand::execute(Document& doc) { apply(doc, angle_); }

void RotateBodyCommand::undo(Document& doc) { apply(doc, -angle_); }

}  // namespace sx
