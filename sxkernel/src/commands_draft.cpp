#include "sx/commands_draft.hpp"

#include <BRepOffsetAPI_DraftAngle.hxx>
#include <TopoDS.hxx>

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
}  // namespace

bool DraftCommand::try_execute(Document& doc) {
    if (faces_.empty() || body_.is_null()) return false;

    const Body* b = doc.body(body_);
    if (!b) return false;

    for (const auto& fid : faces_) {
        auto ref = doc.find_subshape(fid);
        if (!ref || ref->kind != EntityKind::Face || ref->body != body_) return false;
    }

    saved_before_ = snapshot(*b);

    BRepOffsetAPI_DraftAngle mk(b->shape);
    for (const auto& fid : faces_) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) {
            saved_before_.reset();
            return false;
        }
        mk.Add(TopoDS::Face(s), pull_direction_, angle_, neutral_plane_);
        if (!mk.AddDone()) {
            saved_before_.reset();
            return false;
        }
    }

    mk.Build();
    if (!mk.IsDone()) {
        saved_before_.reset();
        return false;
    }

    TopoDS_Shape result = mk.Shape();
    if (result.IsNull() || !shape::is_valid(result)) {
        saved_before_.reset();
        return false;
    }

    doc.replace_body_shape(body_, result);
    saved_after_ = snapshot(*doc.body(body_));
    return true;
}

void DraftCommand::execute(Document& doc) { (void)try_execute(doc); }

void DraftCommand::undo(Document& doc) {
    if (!saved_before_) return;
    doc.remove_body(body_);
    Body copy = snap(saved_before_);
    doc.restore_body(std::move(copy));
}

void DraftCommand::redo(Document& doc) {
    if (!saved_after_) return;
    doc.remove_body(body_);
    Body copy = snap(saved_after_);
    doc.restore_body(std::move(copy));
}

}  // namespace sx
