#pragma once
// Dress-up commands: fillet and chamfer on body edges.

#include <string>
#include <vector>

#include "sx/command.hpp"
#include "sx/ids.hpp"

namespace sx {

class FilletCommand : public Command {
public:
    FilletCommand(std::vector<EntityId> edges, double radius)
        : edges_(std::move(edges)), radius_(radius) {}
    std::string label() const override { return "Fillet"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    std::vector<EntityId> edges_;
    double radius_;
    EntityId body_;
    std::shared_ptr<void> saved_before_;
    std::shared_ptr<void> saved_after_;
};

class ChamferCommand : public Command {
public:
    ChamferCommand(std::vector<EntityId> edges, double distance)
        : edges_(std::move(edges)), distance_(distance) {}
    std::string label() const override { return "Chamfer"; }
    void execute(Document& doc) override;
    void undo(Document& doc) override;
    void redo(Document& doc) override;

private:
    std::vector<EntityId> edges_;
    double distance_;
    EntityId body_;
    std::shared_ptr<void> saved_before_;
    std::shared_ptr<void> saved_after_;
};

}  // namespace sx
