#pragma once
// Sweep and loft feature commands (sketch profile → solid body).

#include <array>
#include <memory>
#include <string>
#include <vector>

#include "sx/command.hpp"
#include "sx/ids.hpp"
#include "sx/sketch.hpp"

namespace sx {

// Sweeps a closed sketch profile along a 3D path, producing a solid body.
// Path is either a polyline (straight segments between model-space points)
// or a circular arc (center + axis + sweep angle in radians; arc starts at
// the sketch plane origin).
class SweepCommand : public Command {
public:
    SweepCommand(std::shared_ptr<const Sketch> profile,
                 std::vector<std::array<double, 3>> path_points, std::string name = "");

    // Circular-arc path: arc of `angle` radians about (center, axis), starting
    // at the sketch plane origin (must not lie on the axis).
    SweepCommand(std::shared_ptr<const Sketch> profile, std::array<double, 3> center,
                 std::array<double, 3> axis, double angle, std::string name = "");

    std::string label() const override { return "Sweep " + name_; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;
    const EntityId& created_body() const { return body_; }

private:
    std::shared_ptr<const Sketch> profile_;
    std::vector<std::array<double, 3>> path_points_;
    bool arc_path_ = false;
    std::array<double, 3> arc_center_{};
    std::array<double, 3> arc_axis_{};
    double arc_angle_ = 0;
    std::string name_;
    EntityId body_;
    std::shared_ptr<void> saved_;
};

// Lofts through two or more closed sketch profiles (each on its own plane).
// Uses BRepOffsetAPI_ThruSections with isSolid=true.
class LoftCommand : public Command {
public:
    LoftCommand(std::vector<std::shared_ptr<const Sketch>> profiles, bool ruled = false,
                std::string name = "");

    std::string label() const override { return "Loft " + name_; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;
    const EntityId& created_body() const { return body_; }

private:
    std::vector<std::shared_ptr<const Sketch>> profiles_;
    bool ruled_;
    std::string name_;
    EntityId body_;
    std::shared_ptr<void> saved_;
};

}  // namespace sx
