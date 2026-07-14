#pragma once
// SxDocument: the Godot-facing wrapper around the sxkernel Document plus its
// command stack. All ids cross the boundary as UUID strings.

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

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

    // --- shell / offset / draft ---
    bool shell_body(const godot::PackedStringArray& faces_to_remove, double thickness);
    bool offset_body(const godot::String& body_id, double offset);
    // angle_deg is converted to radians for the kernel. Pull direction and
    // neutral plane are in model space. Returns false without stacking on
    // invalid input or OCCT failure.
    bool draft_faces(const godot::PackedStringArray& face_ids, double angle_deg,
                     const godot::Vector3& pull_dir, const godot::Vector3& neutral_point,
                     const godot::Vector3& neutral_normal);

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
    bool rename_body(const godot::String& body_id, const godot::String& name);
    bool set_body_color(const godot::String& body_id, const godot::Color& color);
    godot::Color get_body_color(const godot::String& body_id) const;
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
    godot::String get_card_alias(const godot::String& entity_id) const;
    godot::String get_card_notes(const godot::String& entity_id) const;
    // Whole-document markdown bundle (timeline + bodies + cards) for AI use.
    godot::String export_context() const;

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
    // Axis in sketch 2D coordinates (point + direction on the sketch plane).
    godot::String graph_add_revolve(const godot::String& sketch_fid,
                                    const godot::Vector2& axis_point,
                                    const godot::Vector2& axis_dir, double angle,
                                    const godot::String& op, const godot::String& target_fid);
    // Sweep a sketch profile along a 3D polyline path (at least two points).
    godot::String graph_add_sweep(const godot::String& sketch_fid,
                                  const godot::PackedVector3Array& path);
    // Loft through two or more sketch profiles (each on its own plane).
    godot::String graph_add_loft(const godot::PackedStringArray& sketch_fids, bool ruled);
    // Dress-up features on a timeline body. Edge ids are converted to the
    // 1-based edge-map indices the graph stores.
    godot::String graph_add_fillet(const godot::String& target_fid,
                                   const godot::PackedStringArray& edge_ids, double radius);
    godot::String graph_add_chamfer(const godot::String& target_fid,
                                    const godot::PackedStringArray& edge_ids, double distance);
    // Drill a parametric hole into a timeline body's output. type:
    // "simple" | "counterbore" | "countersink". depth <= 0 = through-all.
    godot::String graph_add_hole(const godot::String& target_fid, const godot::String& type,
                                 const godot::Vector3& position, const godot::Vector3& direction,
                                 float diameter, float depth, float cb_diameter, float cb_depth,
                                 float cs_diameter, float cs_angle_deg);
    bool graph_set_params(const godot::String& fid, const godot::String& params_json);
    bool graph_set_suppressed(const godot::String& fid, bool suppressed);
    bool graph_remove(const godot::String& fid);
    // Returns {ok: bool, error: String}.
    godot::Dictionary graph_regenerate();

    // --- variables (equations table) ---
    // Upsert / remove a named expression. Both go through apply_graph_edit so
    // they regenerate and are undoable (the table serializes with the graph).
    // remove_variable keeps the removal even if regenerate fails (features may
    // still reference the name); inspect via graph_regenerate / undo.
    bool set_variable(const godot::String& name, const godot::String& expr);
    bool remove_variable(const godot::String& name);
    // Array of {name, expr, value (float; NAN on error), error: String}.
    godot::Array list_variables() const;

    // --- persistence ---
    bool save(const godot::String& path);
    bool load(const godot::String& path);

    // --- datums (reference geometry) ---
    godot::String add_datum_plane(const godot::Vector3& point, const godot::Vector3& normal);
    godot::String add_datum_axis(const godot::Vector3& point, const godot::Vector3& dir);
    godot::String add_datum_point(const godot::Vector3& p);
    godot::Array datum_list() const;
    bool remove_datum(const godot::String& id);

protected:
    static void _bind_methods();

private:
    godot::String add_primitive(sx::PrimitiveType type, double a, double b, double c,
                                const godot::Vector3& origin);
    bool apply_graph_edit(const std::string& label, const std::function<bool()>& mutate);
    godot::String graph_add_dressup(bool fillet, const godot::String& target_fid,
                                    const godot::PackedStringArray& edge_ids, double value);

    std::unique_ptr<sx::Document> doc_;
    sx::CommandStack stack_;
};

}  // namespace sx_godot
