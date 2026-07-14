#include "sx/commands_dress.hpp"

#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <TopoDS.hxx>

#include <stdexcept>

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

// Resolve edge ids; all must be Edge subshapes of the same body.
EntityId validate_edges(Document& doc, const std::vector<EntityId>& edges, const char* what) {
    if (edges.empty())
        throw std::invalid_argument(std::string(what) + ": no edges");

    EntityId body_id;
    for (const auto& eid : edges) {
        auto ref = doc.find_subshape(eid);
        if (!ref || ref->kind != EntityKind::Edge)
            throw std::invalid_argument(std::string(what) + ": id is not an edge");
        if (body_id.is_null()) {
            body_id = ref->body;
        } else if (body_id != ref->body) {
            throw std::invalid_argument(std::string(what) + ": edges belong to different bodies");
        }
    }
    return body_id;
}
}  // namespace

// --- FilletCommand ---

void FilletCommand::execute(Document& doc) {
    body_ = validate_edges(doc, edges_, "FilletCommand");
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("FilletCommand: body missing");

    saved_before_ = snapshot(*b);

    BRepFilletAPI_MakeFillet mk(b->shape);
    for (const auto& eid : edges_) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull()) throw std::invalid_argument("FilletCommand: edge not found");
        mk.Add(radius_, TopoDS::Edge(s));
    }
    mk.Build();
    if (!mk.IsDone())
        throw std::runtime_error("FilletCommand: fillet failed");

    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        throw std::runtime_error("FilletCommand: result is null or invalid");

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
}

void FilletCommand::undo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void FilletCommand::redo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

// --- ChamferCommand ---

void ChamferCommand::execute(Document& doc) {
    body_ = validate_edges(doc, edges_, "ChamferCommand");
    const Body* b = doc.body(body_);
    if (!b) throw std::invalid_argument("ChamferCommand: body missing");

    saved_before_ = snapshot(*b);

    BRepFilletAPI_MakeChamfer mk(b->shape);
    for (const auto& eid : edges_) {
        TopoDS_Shape s = doc.resolve(eid);
        if (s.IsNull()) throw std::invalid_argument("ChamferCommand: edge not found");
        mk.Add(distance_, TopoDS::Edge(s));
    }
    mk.Build();
    if (!mk.IsDone())
        throw std::runtime_error("ChamferCommand: chamfer failed");

    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result))
        throw std::runtime_error("ChamferCommand: result is null or invalid");

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
}

void ChamferCommand::undo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void ChamferCommand::redo(Document& doc) {
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
