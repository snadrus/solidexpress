#pragma once
// SxSketch: Godot-facing wrapper for sx::Sketch + solver. Entities and
// constraints are addressed by UUID strings; point roles by string
// ("self"|"start"|"end"|"center"); constraint types by string matching
// sx::to_string(ConstraintType).

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <memory>

#include "sx/sketch.hpp"
#include "sx/solver.hpp"

namespace sx_godot {

class SxSketch : public godot::RefCounted {
    GDCLASS(SxSketch, godot::RefCounted)

public:
    SxSketch();
    ~SxSketch() override = default;

    void set_plane(const godot::Vector3& origin, const godot::Vector3& x_dir,
                   const godot::Vector3& y_dir);

    // --- entities (sketch 2D coordinates) ---
    godot::String add_point(double x, double y);
    godot::String add_line(double x1, double y1, double x2, double y2);
    godot::String add_circle(double cx, double cy, double r);
    godot::String add_arc(double cx, double cy, double r, double start_angle, double end_angle);
    bool remove_entity(const godot::String& id);
    void set_construction(const godot::String& id, bool construction);
    godot::PackedStringArray entity_ids() const;

    // Geometry snapshot for rendering:
    // {type: "line", start: Vector2, end: Vector2, construction: bool} etc.
    godot::Dictionary entity_info(const godot::String& id) const;

    // --- constraints ---
    // refs: Array of Dictionaries {entity: String, role: String}.
    godot::String add_constraint(const godot::String& type, const godot::Array& refs,
                                 double value);
    bool remove_constraint(const godot::String& id);
    bool set_constraint_value(const godot::String& id, double value);
    godot::PackedStringArray constraint_ids() const;

    // --- solving ---
    // Returns {status: "success"|"converged"|"failed", dofs: int,
    //          conflicting: PackedStringArray, redundant: PackedStringArray}.
    godot::Dictionary solve();

    // Shared access for SxDocument::extrude_sketch / revolve_sketch.
    std::shared_ptr<sx::Sketch> sketch() const { return sketch_; }

protected:
    static void _bind_methods();

private:
    std::shared_ptr<sx::Sketch> sketch_;
    std::unique_ptr<sx::SolverBackend> solver_;
};

}  // namespace sx_godot
