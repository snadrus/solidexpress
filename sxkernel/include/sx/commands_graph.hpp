#pragma once
// Undoable feature-graph edits. Since the graph is plain structured data,
// undo/redo is implemented as whole-graph snapshots (JSON) plus regenerate.
// Callers mutate the graph first, then push a GraphSnapshotCommand with the
// before/after states; execute/undo restore the corresponding snapshot.

#include <nlohmann/json.hpp>

#include <string>

#include "sx/command.hpp"

namespace sx {

class GraphSnapshotCommand : public Command {
public:
    GraphSnapshotCommand(std::string label, nlohmann::json before, nlohmann::json after)
        : label_(std::move(label)), before_(std::move(before)), after_(std::move(after)) {}

    std::string label() const override { return label_; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;

private:
    static void restore(Document& doc, const nlohmann::json& snapshot);
    std::string label_;
    nlohmann::json before_;
    nlohmann::json after_;
};

}  // namespace sx
