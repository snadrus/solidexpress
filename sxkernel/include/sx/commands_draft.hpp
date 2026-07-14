#pragma once
// Draft (taper) dress-up command: incline selected faces about a neutral plane.

#include <gp_Dir.hxx>
#include <gp_Pln.hxx>

#include <string>
#include <vector>

#include "sx/command.hpp"
#include "sx/ids.hpp"

namespace sx {

// Apply a mold-release draft to selected faces of a body via BRepOffsetAPI_DraftAngle.
class DraftCommand : public Command {
public:
    DraftCommand(EntityId body, std::vector<EntityId> faces, double angle,
                 const gp_Dir& pull_direction, const gp_Pln& neutral_plane)
        : body_(std::move(body)),
          faces_(std::move(faces)),
          angle_(angle),
          pull_direction_(pull_direction),
          neutral_plane_(neutral_plane) {}

    std::string label() const override { return "Draft"; }

    // Returns false and leaves the document untouched on invalid input or
    // algorithm failure. Command::execute delegates here (no-op on failure).
    bool try_execute(Document& doc);

    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    EntityId body_;
    std::vector<EntityId> faces_;
    double angle_;
    gp_Dir pull_direction_;
    gp_Pln neutral_plane_;
    std::shared_ptr<void> saved_before_;
    std::shared_ptr<void> saved_after_;
};

}  // namespace sx
