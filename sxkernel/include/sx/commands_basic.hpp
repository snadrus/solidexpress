#pragma once
// Phase-0/1 commands: primitive creation, delete, transform, push/pull.

#include <array>
#include <string>

#include "sx/command.hpp"
#include "sx/ids.hpp"
#include "sx/shape_utils.hpp"

#include <TopoDS_Shape.hxx>

namespace sx {

enum class PrimitiveType { Box, Cylinder, Sphere, Cone, Torus };

struct PrimitiveParams {
    PrimitiveType type = PrimitiveType::Box;
    // Interpretation per type:
    //   Box: a=dx b=dy c=dz | Cylinder: a=r b=h | Sphere: a=r
    //   Cone: a=r1 b=r2 c=h | Torus: a=R b=r
    double a = 10, b = 10, c = 10;
    shape::Placement placement;
    std::string name;  // empty -> auto ("Box 1", ...)
};

class AddPrimitiveCommand : public Command {
public:
    explicit AddPrimitiveCommand(PrimitiveParams p) : params_(std::move(p)) {}
    std::string label() const override;
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    // Set after execute():
    const EntityId& created_body() const { return body_; }

private:
    PrimitiveParams params_;
    EntityId body_;
    struct SavedBody;            // full snapshot for exact redo restore
    std::shared_ptr<void> saved_;  // type-erased snapshot (Body clone)
    void redo(Document& doc) override;
};

class DeleteBodyCommand : public Command {
public:
    explicit DeleteBodyCommand(EntityId body) : body_(std::move(body)) {}
    std::string label() const override { return "Delete body"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    EntityId body_;
    std::shared_ptr<void> saved_;
};

// Translate a body by a vector (gizmo move). Undo applies the inverse.
class TranslateBodyCommand : public Command {
public:
    TranslateBodyCommand(EntityId body, std::array<double, 3> delta)
        : body_(std::move(body)), delta_(delta) {}
    std::string label() const override { return "Move body"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;

private:
    void apply(Document& doc, const std::array<double, 3>& d);
    EntityId body_;
    std::array<double, 3> delta_;
};

// Push/pull: offset a planar face by `distance` along its outward normal
// (positive = add material). Implemented as prism + boolean fuse/cut.
class PushPullCommand : public Command {
public:
    PushPullCommand(EntityId face, double distance)
        : face_(std::move(face)), distance_(distance) {}
    std::string label() const override { return "Push/pull face"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    EntityId face_;
    double distance_;
    EntityId body_;
    std::shared_ptr<void> saved_before_;  // body snapshot before
    std::shared_ptr<void> saved_after_;   // body snapshot after (for redo)
};

}  // namespace sx
