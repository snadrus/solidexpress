#include "sx/commands_boolean.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <TopoDS_Shape.hxx>

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

TopoDS_Shape run_boolean(BooleanOp op, const TopoDS_Shape& target, const TopoDS_Shape& tool) {
    switch (op) {
        case BooleanOp::Fuse: return BRepAlgoAPI_Fuse(target, tool).Shape();
        case BooleanOp::Cut: return BRepAlgoAPI_Cut(target, tool).Shape();
        case BooleanOp::Common: return BRepAlgoAPI_Common(target, tool).Shape();
    }
    throw std::invalid_argument("BooleanCommand: unknown op");
}
}  // namespace

std::string BooleanCommand::label() const {
    switch (op_) {
        case BooleanOp::Fuse: return "Boolean fuse";
        case BooleanOp::Cut: return "Boolean cut";
        case BooleanOp::Common: return "Boolean common";
    }
    return "Boolean";
}

void BooleanCommand::execute(Document& doc) {
    const Body* target = doc.body(target_);
    const Body* tool = doc.body(tool_);
    if (!target || !tool)
        throw std::invalid_argument("BooleanCommand: id is not a body");

    saved_target_before_ = snapshot(*target);
    saved_tool_before_ = snapshot(*tool);

    TopoDS_Shape result = run_boolean(op_, target->shape, tool->shape);
    if (result.IsNull() || !shape::is_valid(result))
        throw std::runtime_error("BooleanCommand: boolean result is null or invalid");

    doc.replace_body_shape(target_, result);
    saved_target_after_ = snapshot(*doc.body(target_));

    if (keep_tool_) {
        saved_tool_after_ = snapshot(*doc.body(tool_));
    } else {
        doc.remove_body(tool_);
    }
}

void BooleanCommand::undo(Document& doc) {
    if (doc.body(target_)) doc.remove_body(target_);
    if (doc.body(tool_)) doc.remove_body(tool_);
    Body t = snap(saved_target_before_);
    Body u = snap(saved_tool_before_);
    doc.restore_body(std::move(t));
    doc.restore_body(std::move(u));
}

void BooleanCommand::redo(Document& doc) {
    if (doc.body(target_)) doc.remove_body(target_);
    if (doc.body(tool_)) doc.remove_body(tool_);
    Body t = snap(saved_target_after_);
    doc.restore_body(std::move(t));
    if (keep_tool_) {
        Body u = snap(saved_tool_after_);
        doc.restore_body(std::move(u));
    }
}

}  // namespace sx
