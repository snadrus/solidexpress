#pragma once
// Boolean fuse / cut / common as undoable commands.

#include <memory>
#include <string>

#include "sx/command.hpp"
#include "sx/ids.hpp"

namespace sx {

enum class BooleanOp { Fuse, Cut, Common };

// Computes target ⊕ tool (Fuse/Cut/Common), replaces the target body's shape
// with the result, and removes the tool body unless keep_tool.
class BooleanCommand : public Command {
public:
    BooleanCommand(EntityId target, EntityId tool, BooleanOp op, bool keep_tool = false)
        : target_(std::move(target)),
          tool_(std::move(tool)),
          op_(op),
          keep_tool_(keep_tool) {}

    std::string label() const override;
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    EntityId target_;
    EntityId tool_;
    BooleanOp op_;
    bool keep_tool_;

    std::shared_ptr<void> saved_target_before_;
    std::shared_ptr<void> saved_tool_before_;
    std::shared_ptr<void> saved_target_after_;
    std::shared_ptr<void> saved_tool_after_;  // only when keep_tool_
};

}  // namespace sx
