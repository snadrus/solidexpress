#pragma once
// Hole feature: drill a simple, counterbore, or countersink hole into a body.

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <string>

#include "sx/command.hpp"
#include "sx/ids.hpp"

namespace sx {

enum class HoleType { Simple, Counterbore, Countersink };

// Cut a cylindrical (optionally counterbored/countersunk) hole from a body.
// `direction` points into the material. Depth <= 0 means through-all (v1: 1e6).
// For Counterbore, secondary_diameter/param are CB diameter and depth.
// For Countersink, they are CS diameter and included angle (radians).
class HoleCommand : public Command {
public:
    HoleCommand(EntityId body, const gp_Pnt& position, const gp_Dir& direction,
                double diameter, double depth, HoleType type = HoleType::Simple,
                double secondary_diameter = 0.0, double secondary_param = 0.0)
        : body_(std::move(body)),
          position_(position),
          direction_(direction),
          diameter_(diameter),
          depth_(depth),
          type_(type),
          secondary_diameter_(secondary_diameter),
          secondary_param_(secondary_param) {}

    std::string label() const override { return "Hole"; }

    // Returns false and leaves the document untouched on invalid input or
    // algorithm failure. Command::execute delegates here (no-op on failure).
    bool try_execute(Document& doc);

    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    EntityId body_;
    gp_Pnt position_;
    gp_Dir direction_;
    double diameter_;
    double depth_;
    HoleType type_;
    double secondary_diameter_;
    double secondary_param_;
    std::shared_ptr<void> saved_before_;
    std::shared_ptr<void> saved_after_;
};

}  // namespace sx
