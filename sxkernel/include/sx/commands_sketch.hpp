#pragma once
// Sketch-based feature commands: extrude (pad) and revolve.

#include <memory>
#include <string>

#include "sx/command.hpp"
#include "sx/ids.hpp"
#include "sx/sketch.hpp"

namespace sx {

// Extrudes the sketch's closed profile along the sketch plane normal.
// distance > 0 extrudes along +normal. If `symmetric`, half each way.
class ExtrudeCommand : public Command {
public:
    ExtrudeCommand(std::shared_ptr<const Sketch> sketch, double distance,
                   bool symmetric = false, std::string name = "");
    std::string label() const override { return "Extrude " + name_; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;
    const EntityId& created_body() const { return body_; }

private:
    std::shared_ptr<const Sketch> sketch_;
    double distance_;
    bool symmetric_;
    std::string name_;
    EntityId body_;
    std::shared_ptr<void> saved_;
};

// Revolves the sketch's closed profile around an axis in the sketch plane,
// defined in sketch 2D coords by a point and direction. angle in radians.
class RevolveCommand : public Command {
public:
    RevolveCommand(std::shared_ptr<const Sketch> sketch,
                   std::array<double, 2> axis_point, std::array<double, 2> axis_dir,
                   double angle, std::string name = "");
    std::string label() const override { return "Revolve " + name_; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;
    const EntityId& created_body() const { return body_; }

private:
    std::shared_ptr<const Sketch> sketch_;
    std::array<double, 2> axis_point_;
    std::array<double, 2> axis_dir_;
    double angle_;
    std::string name_;
    EntityId body_;
    std::shared_ptr<void> saved_;
};

}  // namespace sx
