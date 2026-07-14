#pragma once
// Hollow/shell and body-offset dress-up commands.

#include <string>
#include <vector>

#include "sx/command.hpp"
#include "sx/ids.hpp"

namespace sx {

// Remove selected faces and offset the remaining shell inward by `thickness`,
// producing a hollow solid (open where faces were removed).
class ShellCommand : public Command {
public:
    ShellCommand(std::vector<EntityId> faces_to_remove, double thickness)
        : faces_(std::move(faces_to_remove)), thickness_(thickness) {}
    std::string label() const override { return "Shell"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    std::vector<EntityId> faces_;
    double thickness_;
    EntityId body_;
    std::shared_ptr<void> saved_before_;
    std::shared_ptr<void> saved_after_;
};

// Offset every face of a body by `offset` (positive = outward, negative = inward).
class OffsetBodyCommand : public Command {
public:
    OffsetBodyCommand(EntityId body, double offset)
        : body_(std::move(body)), offset_(offset) {}
    std::string label() const override { return "Offset body"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    EntityId body_;
    double offset_;
    std::shared_ptr<void> saved_before_;
    std::shared_ptr<void> saved_after_;
};

}  // namespace sx
