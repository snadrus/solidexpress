#include "sx/commands_basic.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <TopoDS.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <stdexcept>

#include "sx/document.hpp"

namespace sx {

namespace {
// Snapshot of a Body, used to restore exact ids on undo/redo.
std::shared_ptr<void> snapshot(const Body& b) {
    return std::make_shared<Body>(b);
}
const Body& snap(const std::shared_ptr<void>& p) {
    return *static_cast<const Body*>(p.get());
}

int primitive_counter = 0;

std::string default_name(PrimitiveType t) {
    ++primitive_counter;
    const char* base = "Body";
    switch (t) {
        case PrimitiveType::Box: base = "Box"; break;
        case PrimitiveType::Cylinder: base = "Cylinder"; break;
        case PrimitiveType::Sphere: base = "Sphere"; break;
        case PrimitiveType::Cone: base = "Cone"; break;
        case PrimitiveType::Torus: base = "Torus"; break;
    }
    return std::string(base) + " " + std::to_string(primitive_counter);
}

TopoDS_Shape build_primitive(const PrimitiveParams& p) {
    switch (p.type) {
        case PrimitiveType::Box: return shape::make_box(p.a, p.b, p.c, p.placement);
        case PrimitiveType::Cylinder: return shape::make_cylinder(p.a, p.b, p.placement);
        case PrimitiveType::Sphere: return shape::make_sphere(p.a, p.placement);
        case PrimitiveType::Cone: return shape::make_cone(p.a, p.b, p.c, p.placement);
        case PrimitiveType::Torus: return shape::make_torus(p.a, p.b, p.placement);
    }
    throw std::invalid_argument("unknown primitive type");
}
}  // namespace

// --- AddPrimitiveCommand ---

std::string AddPrimitiveCommand::label() const {
    return "Add " + (params_.name.empty() ? std::string("primitive") : params_.name);
}

void AddPrimitiveCommand::execute(Document& doc) {
    if (params_.name.empty()) params_.name = default_name(params_.type);
    body_ = doc.add_body(build_primitive(params_), params_.name);
    saved_ = snapshot(*doc.body(body_));
}

void AddPrimitiveCommand::undo(Document& doc) { doc.remove_body(body_); }

void AddPrimitiveCommand::redo(Document& doc) {
    Body copy = snap(saved_);
    doc.restore_body(std::move(copy));
}

// --- DeleteBodyCommand ---

void DeleteBodyCommand::execute(Document& doc) {
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("DeleteBodyCommand: no such body");
    saved_ = snapshot(*b);
    doc.remove_body(body_);
}

void DeleteBodyCommand::undo(Document& doc) {
    Body copy = snap(saved_);
    doc.restore_body(std::move(copy));
}

void DeleteBodyCommand::redo(Document& doc) { doc.remove_body(body_); }

// --- TranslateBodyCommand ---

void TranslateBodyCommand::apply(Document& doc, const std::array<double, 3>& d) {
    Body* b = doc.body_mut(body_);
    if (!b) throw std::invalid_argument("TranslateBodyCommand: no such body");
    gp_Trsf t;
    t.SetTranslation(gp_Vec(d[0], d[1], d[2]));
    // Translation preserves topology, so subshape ids stay valid: apply the
    // transform without re-registering.
    BRepBuilderAPI_Transform xform(b->shape, t, /*copy=*/false);
    b->shape = xform.Shape();
    doc.bump_revision();
}

void TranslateBodyCommand::execute(Document& doc) { apply(doc, delta_); }

void TranslateBodyCommand::undo(Document& doc) {
    apply(doc, {-delta_[0], -delta_[1], -delta_[2]});
}

// --- PushPullCommand ---

void PushPullCommand::execute(Document& doc) {
    auto ref = doc.find_subshape(face_);
    if (!ref || ref->kind != EntityKind::Face)
        throw std::invalid_argument("PushPullCommand: id is not a face");
    body_ = ref->body;
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("PushPullCommand: body missing");

    TopoDS_Shape face_shape = doc.resolve(face_);
    if (face_shape.IsNull()) throw std::invalid_argument("PushPullCommand: face not found");
    TopoDS_Face face = TopoDS::Face(face_shape);

    BRepAdaptor_Surface surf(face);
    if (surf.GetType() != GeomAbs_Plane)
        throw std::invalid_argument("PushPullCommand: only planar faces supported (v0)");

    gp_Dir normal = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) normal.Reverse();

    saved_before_ = snapshot(*b);

    const double dist = std::abs(distance_);
    gp_Vec sweep(normal.XYZ() * (distance_ >= 0 ? dist : dist));
    TopoDS_Shape tool = BRepPrimAPI_MakePrism(face, sweep).Shape();

    TopoDS_Shape result;
    if (distance_ >= 0) {
        result = BRepAlgoAPI_Fuse(b->shape, tool).Shape();
    } else {
        // Cut: sweep the face inward (opposite the outward normal).
        gp_Vec inward(normal.Reversed().XYZ() * dist);
        tool = BRepPrimAPI_MakePrism(face, inward).Shape();
        result = BRepAlgoAPI_Cut(b->shape, tool).Shape();
    }
    if (result.IsNull()) throw std::runtime_error("PushPullCommand: boolean failed");

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
}

void PushPullCommand::undo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void PushPullCommand::redo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
