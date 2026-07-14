#pragma once
// SxDocument: the Godot-facing wrapper around the sxkernel Document plus its
// command stack. All ids cross the boundary as UUID strings.

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <functional>
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
    // op: "fuse" | "cut" | "common". Tool body is consumed unless keep_tool.
    bool boolean_op(const godot::String& target_body, const godot::String& tool_body,
                    const godot::String& op, bool keep_tool);
    bool fillet_edges(const godot::PackedStringArray& edge_ids, double radius);
    bool chamfer_edges(const godot::PackedStringArray& edge_ids, double distance);

    // --- transforms & patterns ---
    // Returns the new body's uuid ("" on failure).
    godot::String mirror_body(const godot::String& body_id, const godot::Vector3& plane_point,
                              const godot::Vector3& plane_normal, bool keep_original);
    // Returns uuids of the new copies (count includes the original).
    godot::PackedStringArray linear_pattern(const godot::String& body_id,
                                            const godot::Vector3& direction, double spacing,
                                            int count);
    godot::PackedStringArray circular_pattern(const godot::String& body_id,
                                              const godot::Vector3& axis_point,
                                              const godot::Vector3& axis_dir, int count,
                                              double total_angle);
    bool rotate_body(const godot::String& body_id, const godot::Vector3& axis_point,
                     const godot::Vector3& axis_dir, double angle);

    // --- shell / offset ---
    bool shell_body(const godot::PackedStringArray& faces_to_remove, double thickness);
    bool offset_body(const godot::String& body_id, double offset);

    // --- measurement ---
    // {distance: float, point_a: Vector3, point_b: Vector3} or {} on failure.
    godot::Dictionary measure_distance(const godot::String& a, const godot::String& b) const;
    // {min: Vector3, max: Vector3} or {}.
    godot::Dictionary measure_bbox(const godot::String& id) const;
    // {volume, surface_area, center_of_mass: Vector3} or {}.
    godot::Dictionary measure_mass(const godot::String& body_id) const;
    double measure_edge_length(const godot::String& edge_id) const;
    double measure_face_area(const godot::String& face_id) const;
    // Radians; -1.0 when faces are not planar / invalid.
    double measure_face_angle(const godot::String& f1, const godot::String& f2) const;

    // --- interop ---
    bool export_step(const godot::String& path);
    bool export_stl(const godot::String& path, bool binary);
    // Returns uuids of imported bodies (empty on failure).
    godot::PackedStringArray import_step(const godot::String& path);

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
    godot::PackedStringArray get_edge_ids(const godot::String& body_id) const;
    // Edge wireframe as a Dictionary {edge_uuid: PackedVector3Array}.
    godot::Dictionary get_edge_lines(const godot::String& body_id) const;

    // Exact B-rep picking. Returns {} on miss, else
    // {body: String, face: String, point: Vector3, distance: float}.
    godot::Dictionary pick(const godot::Vector3& origin, const godot::Vector3& direction) const;

    // --- semantic cards ---
    godot::String card_markdown(const godot::String& entity_id) const;
    void set_card_alias(const godot::String& entity_id, const godot::String& text);
    void set_card_notes(const godot::String& entity_id, const godot::String& text);

    // --- feature graph (parametric timeline) ---
    // Features are returned as Dictionaries {id, name, type, suppressed,
    // params (JSON string), output_body}. Graph mutations regenerate the
    // document immediately and are undoable (whole-graph snapshots).
    godot::Array graph_features() const;
    godot::String graph_add_primitive(const godot::String& kind, double a, double b, double c,
                                      const godot::Vector3& origin);
    godot::String graph_add_sketch(const godot::Ref<class SxSketch>& sketch);
    // op: "new" | "fuse" | "cut"; target_fid required for fuse/cut.
    godot::String graph_add_extrude(const godot::String& sketch_fid, double distance,
                                    bool symmetric, const godot::String& op,
                                    const godot::String& target_fid);
    bool graph_set_params(const godot::String& fid, const godot::String& params_json);
    bool graph_set_suppressed(const godot::String& fid, bool suppressed);
    bool graph_remove(const godot::String& fid);
    // Returns {ok: bool, error: String}.
    godot::Dictionary graph_regenerate();

    // --- persistence ---
    bool save(const godot::String& path);
    bool load(const godot::String& path);

protected:
    static void _bind_methods();

private:
    godot::String add_primitive(sx::PrimitiveType type, double a, double b, double c,
                                const godot::Vector3& origin);
    bool apply_graph_edit(const std::string& label, const std::function<bool()>& mutate);

    std::unique_ptr<sx::Document> doc_;
    sx::CommandStack stack_;
};

}  // namespace sx_godot
