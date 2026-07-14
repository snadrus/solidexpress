#pragma once
// SxDocument: the Godot-facing wrapper around the sxkernel Document plus its
// command stack. All ids cross the boundary as UUID strings.

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <memory>

#include "sx/command.hpp"
#include "sx/commands_basic.hpp"
#include "sx/document.hpp"

namespace sx_godot {

class SxDocument : public godot::RefCounted {
    GDCLASS(SxDocument, godot::RefCounted)

public:
    SxDocument();
    ~SxDocument() override = default;

    // --- creation (drag-and-drop palette) ---
    godot::String add_box(double dx, double dy, double dz, const godot::Vector3& origin);
    godot::String add_cylinder(double radius, double height, const godot::Vector3& origin);
    godot::String add_sphere(double radius, const godot::Vector3& origin);
    godot::String add_cone(double r1, double r2, double height, const godot::Vector3& origin);
    godot::String add_torus(double major_r, double minor_r, const godot::Vector3& origin);

    // --- sketch features ---
    // Extrudes the sketch's closed profile along its plane normal; returns the
    // new body's uuid ("" on failure).
    godot::String extrude_sketch(const godot::Ref<class SxSketch>& sketch, double distance,
                                 bool symmetric);
    godot::String revolve_sketch(const godot::Ref<class SxSketch>& sketch,
                                 const godot::Vector2& axis_point,
                                 const godot::Vector2& axis_dir, double angle);

    // --- editing ---
    bool delete_body(const godot::String& body_id);
    bool translate_body(const godot::String& body_id, const godot::Vector3& delta);
    bool push_pull(const godot::String& face_id, double distance);

    // --- undo/redo ---
    bool undo();
    bool redo();
    bool can_undo() const;
    bool can_redo() const;

    // --- queries ---
    godot::PackedStringArray body_ids() const;
    godot::String body_name(const godot::String& body_id) const;
    double body_volume(const godot::String& body_id) const;
    uint64_t revision() const;

    // Tessellation: ArrayMesh with one surface per face; surface index order
    // matches get_face_ids(body_id).
    godot::Ref<godot::ArrayMesh> get_mesh(const godot::String& body_id) const;
    godot::PackedStringArray get_face_ids(const godot::String& body_id) const;
    // Edge wireframe as a Dictionary {edge_uuid: PackedVector3Array}.
    godot::Dictionary get_edge_lines(const godot::String& body_id) const;

    // Exact B-rep picking. Returns {} on miss, else
    // {body: String, face: String, point: Vector3, distance: float}.
    godot::Dictionary pick(const godot::Vector3& origin, const godot::Vector3& direction) const;

    // --- semantic cards ---
    godot::String card_markdown(const godot::String& entity_id) const;
    void set_card_alias(const godot::String& entity_id, const godot::String& text);
    void set_card_notes(const godot::String& entity_id, const godot::String& text);

    // --- persistence ---
    bool save(const godot::String& path);
    bool load(const godot::String& path);

protected:
    static void _bind_methods();

private:
    godot::String add_primitive(sx::PrimitiveType type, double a, double b, double c,
                                const godot::Vector3& origin);

    std::unique_ptr<sx::Document> doc_;
    sx::CommandStack stack_;
};

}  // namespace sx_godot
