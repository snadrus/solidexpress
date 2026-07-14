#pragma once
// Transform / pattern commands: mirror, linear/circular pattern, rotate.

#include <array>
#include <cmath>
#include <memory>
#include <string>
#include <vector>

#include "sx/command.hpp"
#include "sx/ids.hpp"

namespace sx {

// Mirror a body across a plane. Creates a new body named "Mirror of <name>".
// If keep_original is false, the source body is removed after mirroring.
class MirrorBodyCommand : public Command {
public:
    MirrorBodyCommand(EntityId body,
                      std::array<double, 3> plane_point,
                      std::array<double, 3> plane_normal,
                      bool keep_original = true)
        : body_(std::move(body)),
          plane_point_(plane_point),
          plane_normal_(plane_normal),
          keep_original_(keep_original) {}

    std::string label() const override { return "Mirror body"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

    const EntityId& created_body() const { return created_; }

private:
    EntityId body_;
    std::array<double, 3> plane_point_;
    std::array<double, 3> plane_normal_;
    bool keep_original_;
    EntityId created_;
    std::shared_ptr<void> saved_original_;  // when !keep_original_
    std::shared_ptr<void> saved_created_;
};

// Creates count-1 copies of a body along a direction at spacing, 2*spacing, ...
// count includes the original (count=4 → 3 new bodies). Names: "<name> [2]", ...
class LinearPatternCommand : public Command {
public:
    LinearPatternCommand(EntityId body,
                         std::array<double, 3> direction,
                         double spacing,
                         int count)
        : body_(std::move(body)),
          direction_(direction),
          spacing_(spacing),
          count_(count) {}

    std::string label() const override { return "Linear pattern"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

    const std::vector<EntityId>& created_bodies() const { return created_; }

private:
    EntityId body_;
    std::array<double, 3> direction_;
    double spacing_;
    int count_;
    std::vector<EntityId> created_;
    std::vector<std::shared_ptr<void>> saved_created_;
};

// Creates count-1 copies rotated about an axis by total_angle/count increments.
class CircularPatternCommand : public Command {
public:
    CircularPatternCommand(EntityId body,
                           std::array<double, 3> axis_point,
                           std::array<double, 3> axis_dir,
                           int count,
                           double total_angle = 2.0 * M_PI)
        : body_(std::move(body)),
          axis_point_(axis_point),
          axis_dir_(axis_dir),
          count_(count),
          total_angle_(total_angle) {}

    std::string label() const override { return "Circular pattern"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

    const std::vector<EntityId>& created_bodies() const { return created_; }

private:
    EntityId body_;
    std::array<double, 3> axis_point_;
    std::array<double, 3> axis_dir_;
    int count_;
    double total_angle_;
    std::vector<EntityId> created_;
    std::vector<std::shared_ptr<void>> saved_created_;
};

// Rotate a body in place about an axis. Topology unchanged → subshape ids stay valid.
class RotateBodyCommand : public Command {
public:
    RotateBodyCommand(EntityId body,
                      std::array<double, 3> axis_point,
                      std::array<double, 3> axis_dir,
                      double angle)
        : body_(std::move(body)),
          axis_point_(axis_point),
          axis_dir_(axis_dir),
          angle_(angle) {}

    std::string label() const override { return "Rotate body"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;

private:
    void apply(Document& doc, double angle);
    EntityId body_;
    std::array<double, 3> axis_point_;
    std::array<double, 3> axis_dir_;
    double angle_;
};

}  // namespace sx
