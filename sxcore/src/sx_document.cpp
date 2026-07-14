#include "sx_document.hpp"

#include <godot_cpp/core/class_db.hpp>

#include "sx/commands_boolean.hpp"
#include "sx/commands_dress.hpp"
#include "sx/commands_graph.hpp"
#include "sx/commands_hollow.hpp"
#include "sx/commands_sketch.hpp"
#include "sx/commands_transform.hpp"
#include "sx/measure.hpp"
#include "sx/features.hpp"
#include "sx/interop.hpp"
#include "sx_sketch.hpp"
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include "sx/cards.hpp"
#include "sx/log.hpp"
#include "sx/pick.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"
#include "sx/tessellate.hpp"

using namespace godot;

namespace sx_godot {

static std::string to_std(const String& s) { return s.utf8().get_data(); }
static String to_gd(const std::string& s) { return String::utf8(s.c_str()); }

static sx::EntityId parse_id(const String& s) {
    try {
        return sx::EntityId::from_string(to_std(s));
    } catch (...) {
        return {};
    }
}

SxDocument::SxDocument() : doc_(std::make_unique<sx::Document>()) {}

String SxDocument::add_primitive(sx::PrimitiveType type, double a, double b, double c,
                                 const Vector3& origin) {
    sx::PrimitiveParams p;
    p.type = type;
    p.a = a;
    p.b = b;
    p.c = c;
    p.placement.origin = {origin.x, origin.y, origin.z};
    auto cmd = std::make_unique<sx::AddPrimitiveCommand>(p);
    sx::AddPrimitiveCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("add_primitive failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

String SxDocument::add_box(double dx, double dy, double dz, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Box, dx, dy, dz, origin);
}
String SxDocument::add_cylinder(double radius, double height, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Cylinder, radius, height, 0, origin);
}
String SxDocument::add_sphere(double radius, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Sphere, radius, 0, 0, origin);
}
String SxDocument::add_cone(double r1, double r2, double height, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Cone, r1, r2, height, origin);
}
String SxDocument::add_torus(double major_r, double minor_r, const Vector3& origin) {
    return add_primitive(sx::PrimitiveType::Torus, major_r, minor_r, 0, origin);
}

String SxDocument::extrude_sketch(const Ref<SxSketch>& sketch, double distance,
                                  bool symmetric) {
    if (sketch.is_null()) return {};
    auto cmd = std::make_unique<sx::ExtrudeCommand>(sketch->sketch(), distance, symmetric);
    sx::ExtrudeCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("extrude failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

String SxDocument::revolve_sketch(const Ref<SxSketch>& sketch, const Vector2& axis_point,
                                  const Vector2& axis_dir, double angle) {
    if (sketch.is_null()) return {};
    auto cmd = std::make_unique<sx::RevolveCommand>(
        sketch->sketch(), std::array<double, 2>{axis_point.x, axis_point.y},
        std::array<double, 2>{axis_dir.x, axis_dir.y}, angle);
    sx::RevolveCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("revolve failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

bool SxDocument::delete_body(const String& body_id) {
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::DeleteBodyCommand>(id));
    } catch (const std::exception& e) {
        sx::log::error(std::string("delete_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::translate_body(const String& body_id, const Vector3& delta) {
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::TranslateBodyCommand>(
                               id, std::array<double, 3>{delta.x, delta.y, delta.z}));
    } catch (const std::exception& e) {
        sx::log::error(std::string("translate_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::push_pull(const String& face_id, double distance) {
    auto id = parse_id(face_id);
    if (id.is_null()) return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::PushPullCommand>(id, distance));
    } catch (const std::exception& e) {
        sx::log::error(std::string("push_pull failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::boolean_op(const String& target_body, const String& tool_body,
                            const String& op, bool keep_tool) {
    auto target = parse_id(target_body);
    auto tool = parse_id(tool_body);
    std::string op_name = to_std(op);
    sx::BooleanOp bop;
    if (op_name == "fuse") bop = sx::BooleanOp::Fuse;
    else if (op_name == "cut") bop = sx::BooleanOp::Cut;
    else if (op_name == "common") bop = sx::BooleanOp::Common;
    else return false;
    try {
        stack_.push(*doc_, std::make_unique<sx::BooleanCommand>(target, tool, bop, keep_tool));
    } catch (const std::exception& e) {
        sx::log::error(std::string("boolean_op failed: ") + e.what());
        return false;
    }
    return true;
}

static std::vector<sx::EntityId> parse_ids(const PackedStringArray& arr) {
    std::vector<sx::EntityId> out;
    for (int i = 0; i < arr.size(); ++i) {
        auto id = parse_id(arr[i]);
        if (!id.is_null()) out.push_back(id);
    }
    return out;
}

bool SxDocument::fillet_edges(const PackedStringArray& edge_ids, double radius) {
    try {
        stack_.push(*doc_, std::make_unique<sx::FilletCommand>(parse_ids(edge_ids), radius));
    } catch (const std::exception& e) {
        sx::log::error(std::string("fillet failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::chamfer_edges(const PackedStringArray& edge_ids, double distance) {
    try {
        stack_.push(*doc_, std::make_unique<sx::ChamferCommand>(parse_ids(edge_ids), distance));
    } catch (const std::exception& e) {
        sx::log::error(std::string("chamfer failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::export_step(const String& path) {
    std::string err;
    bool ok = sx::interop::export_step(*doc_, to_std(path), &err);
    if (!ok) sx::log::error("export_step: " + err);
    return ok;
}

bool SxDocument::export_stl(const String& path, bool binary) {
    std::string err;
    bool ok = sx::interop::export_stl(*doc_, to_std(path), binary, &err);
    if (!ok) sx::log::error("export_stl: " + err);
    return ok;
}

String SxDocument::mirror_body(const String& body_id, const Vector3& plane_point,
                               const Vector3& plane_normal, bool keep_original) {
    auto cmd = std::make_unique<sx::MirrorBodyCommand>(
        parse_id(body_id), std::array<double, 3>{plane_point.x, plane_point.y, plane_point.z},
        std::array<double, 3>{plane_normal.x, plane_normal.y, plane_normal.z}, keep_original);
    sx::MirrorBodyCommand* raw = cmd.get();
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("mirror_body failed: ") + e.what());
        return {};
    }
    return to_gd(raw->created_body().str());
}

PackedStringArray SxDocument::linear_pattern(const String& body_id, const Vector3& direction,
                                             double spacing, int count) {
    auto cmd = std::make_unique<sx::LinearPatternCommand>(
        parse_id(body_id), std::array<double, 3>{direction.x, direction.y, direction.z},
        spacing, count);
    sx::LinearPatternCommand* raw = cmd.get();
    PackedStringArray out;
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("linear_pattern failed: ") + e.what());
        return out;
    }
    for (const auto& id : raw->created_bodies()) out.push_back(to_gd(id.str()));
    return out;
}

PackedStringArray SxDocument::circular_pattern(const String& body_id, const Vector3& axis_point,
                                               const Vector3& axis_dir, int count,
                                               double total_angle) {
    auto cmd = std::make_unique<sx::CircularPatternCommand>(
        parse_id(body_id), std::array<double, 3>{axis_point.x, axis_point.y, axis_point.z},
        std::array<double, 3>{axis_dir.x, axis_dir.y, axis_dir.z}, count, total_angle);
    sx::CircularPatternCommand* raw = cmd.get();
    PackedStringArray out;
    try {
        stack_.push(*doc_, std::move(cmd));
    } catch (const std::exception& e) {
        sx::log::error(std::string("circular_pattern failed: ") + e.what());
        return out;
    }
    for (const auto& id : raw->created_bodies()) out.push_back(to_gd(id.str()));
    return out;
}

bool SxDocument::rotate_body(const String& body_id, const Vector3& axis_point,
                             const Vector3& axis_dir, double angle) {
    try {
        stack_.push(*doc_, std::make_unique<sx::RotateBodyCommand>(
                               parse_id(body_id),
                               std::array<double, 3>{axis_point.x, axis_point.y, axis_point.z},
                               std::array<double, 3>{axis_dir.x, axis_dir.y, axis_dir.z}, angle));
    } catch (const std::exception& e) {
        sx::log::error(std::string("rotate_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::shell_body(const PackedStringArray& faces_to_remove, double thickness) {
    try {
        stack_.push(*doc_, std::make_unique<sx::ShellCommand>(parse_ids(faces_to_remove),
                                                              thickness));
    } catch (const std::exception& e) {
        sx::log::error(std::string("shell_body failed: ") + e.what());
        return false;
    }
    return true;
}

bool SxDocument::offset_body(const String& body_id, double offset) {
    try {
        stack_.push(*doc_, std::make_unique<sx::OffsetBodyCommand>(parse_id(body_id), offset));
    } catch (const std::exception& e) {
        sx::log::error(std::string("offset_body failed: ") + e.what());
        return false;
    }
    return true;
}

Dictionary SxDocument::measure_distance(const String& a, const String& b) const {
    Dictionary out;
    auto r = sx::measure::min_distance(*doc_, parse_id(a), parse_id(b));
    if (!r) return out;
    out["distance"] = r->distance;
    out["point_a"] = Vector3(r->point_a[0], r->point_a[1], r->point_a[2]);
    out["point_b"] = Vector3(r->point_b[0], r->point_b[1], r->point_b[2]);
    return out;
}

Dictionary SxDocument::measure_bbox(const String& id) const {
    Dictionary out;
    auto r = sx::measure::bounding_box(*doc_, parse_id(id));
    if (!r) return out;
    out["min"] = Vector3(r->min[0], r->min[1], r->min[2]);
    out["max"] = Vector3(r->max[0], r->max[1], r->max[2]);
    return out;
}

Dictionary SxDocument::measure_mass(const String& body_id) const {
    Dictionary out;
    auto r = sx::measure::mass_properties(*doc_, parse_id(body_id));
    if (!r) return out;
    out["volume"] = r->volume;
    out["surface_area"] = r->surface_area;
    out["center_of_mass"] =
        Vector3(r->center_of_mass[0], r->center_of_mass[1], r->center_of_mass[2]);
    return out;
}

double SxDocument::measure_edge_length(const String& edge_id) const {
    return sx::measure::edge_length(*doc_, parse_id(edge_id));
}

double SxDocument::measure_face_area(const String& face_id) const {
    return sx::measure::face_area(*doc_, parse_id(face_id));
}

double SxDocument::measure_face_angle(const String& f1, const String& f2) const {
    auto r = sx::measure::angle_between_faces(*doc_, parse_id(f1), parse_id(f2));
    return r ? *r : -1.0;
}

PackedStringArray SxDocument::import_step(const String& path) {
    PackedStringArray out;
    std::string err;
    auto ids = sx::interop::import_step(*doc_, to_std(path), &err);
    if (ids.empty() && !err.empty()) sx::log::error("import_step: " + err);
    for (const auto& id : ids) out.push_back(to_gd(id.str()));
    return out;
}

bool SxDocument::undo() { return stack_.undo(*doc_); }
bool SxDocument::redo() { return stack_.redo(*doc_); }
bool SxDocument::can_undo() const { return stack_.can_undo(); }
bool SxDocument::can_redo() const { return stack_.can_redo(); }

PackedStringArray SxDocument::body_ids() const {
    PackedStringArray out;
    for (const auto& id : doc_->body_ids()) out.push_back(to_gd(id.str()));
    return out;
}

String SxDocument::body_name(const String& body_id) const {
    const sx::Body* b = doc_->body(parse_id(body_id));
    return b ? to_gd(b->name) : String();
}

double SxDocument::body_volume(const String& body_id) const {
    const sx::Body* b = doc_->body(parse_id(body_id));
    return b ? sx::shape::volume(b->shape) : 0.0;
}

uint64_t SxDocument::revision() const { return doc_->revision(); }

Ref<ArrayMesh> SxDocument::get_mesh(const String& body_id) const {
    Ref<ArrayMesh> mesh;
    mesh.instantiate();
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return mesh;

    sx::BodyMesh bm;
    try {
        bm = sx::tessellate_body(*doc_, id);
    } catch (const std::exception& e) {
        sx::log::error(std::string("tessellate failed: ") + e.what());
        return mesh;
    }

    for (const auto& fm : bm.faces) {
        PackedVector3Array positions;
        PackedVector3Array normals;
        PackedInt32Array indices;
        const size_t n = fm.positions.size() / 3;
        positions.resize(static_cast<int64_t>(n));
        normals.resize(static_cast<int64_t>(n));
        for (size_t i = 0; i < n; ++i) {
            positions[static_cast<int64_t>(i)] =
                Vector3(fm.positions[3 * i], fm.positions[3 * i + 1], fm.positions[3 * i + 2]);
            normals[static_cast<int64_t>(i)] =
                Vector3(fm.normals[3 * i], fm.normals[3 * i + 1], fm.normals[3 * i + 2]);
        }
        indices.resize(static_cast<int64_t>(fm.indices.size()));
        for (size_t i = 0; i < fm.indices.size(); ++i)
            indices[static_cast<int64_t>(i)] = static_cast<int32_t>(fm.indices[i]);

        Array arrays;
        arrays.resize(Mesh::ARRAY_MAX);
        arrays[Mesh::ARRAY_VERTEX] = positions;
        arrays[Mesh::ARRAY_NORMAL] = normals;
        arrays[Mesh::ARRAY_INDEX] = indices;
        mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
    }
    return mesh;
}

PackedStringArray SxDocument::get_face_ids(const String& body_id) const {
    PackedStringArray out;
    const sx::Body* b = doc_->body(parse_id(body_id));
    if (!b) return out;
    for (const auto& fid : b->subshape_ids.at(sx::EntityKind::Face))
        out.push_back(to_gd(fid.str()));
    return out;
}

PackedStringArray SxDocument::get_edge_ids(const String& body_id) const {
    PackedStringArray out;
    const sx::Body* b = doc_->body(parse_id(body_id));
    if (!b) return out;
    for (const auto& eid : b->subshape_ids.at(sx::EntityKind::Edge))
        out.push_back(to_gd(eid.str()));
    return out;
}

Dictionary SxDocument::get_edge_lines(const String& body_id) const {
    Dictionary out;
    auto id = parse_id(body_id);
    if (id.is_null() || !doc_->body(id)) return out;
    sx::BodyMesh bm;
    try {
        bm = sx::tessellate_body(*doc_, id);
    } catch (...) {
        return out;
    }
    for (const auto& el : bm.edges) {
        PackedVector3Array pts;
        const size_t n = el.points.size() / 3;
        pts.resize(static_cast<int64_t>(n));
        for (size_t i = 0; i < n; ++i)
            pts[static_cast<int64_t>(i)] =
                Vector3(el.points[3 * i], el.points[3 * i + 1], el.points[3 * i + 2]);
        out[to_gd(el.edge.str())] = pts;
    }
    return out;
}

Dictionary SxDocument::pick(const Vector3& origin, const Vector3& direction) const {
    Dictionary out;
    auto hit = sx::pick_ray(*doc_, {origin.x, origin.y, origin.z},
                            {direction.x, direction.y, direction.z});
    if (!hit) return out;
    out["body"] = to_gd(hit->body.str());
    out["face"] = to_gd(hit->face.str());
    out["point"] = Vector3(static_cast<float>(hit->point[0]),
                           static_cast<float>(hit->point[1]),
                           static_cast<float>(hit->point[2]));
    out["distance"] = hit->distance;
    return out;
}

String SxDocument::card_markdown(const String& entity_id) const {
    const sx::Card* c = doc_->cards().find(parse_id(entity_id));
    return c ? to_gd(c->to_markdown()) : String();
}

void SxDocument::set_card_alias(const String& entity_id, const String& text) {
    doc_->cards().set_alias(parse_id(entity_id), to_std(text));
}

void SxDocument::set_card_notes(const String& entity_id, const String& text) {
    doc_->cards().set_notes(parse_id(entity_id), to_std(text));
}

Array SxDocument::graph_features() const {
    Array out;
    for (const auto& f : doc_->graph().timeline()) {
        Dictionary d;
        d["id"] = to_gd(f.id.str());
        d["name"] = to_gd(f.name);
        d["type"] = to_gd(sx::to_string(f.type));
        d["suppressed"] = f.suppressed;
        d["params"] = to_gd(f.params.dump());
        d["output_body"] = f.output_body.is_null() ? String() : to_gd(f.output_body.str());
        out.push_back(d);
    }
    return out;
}

// Applies a graph mutation as an undoable command. `mutate` edits the graph
// data in place (no regenerate); the command's execute performs the actual
// regenerate. On regeneration failure the graph is rolled back to `before`
// and false is returned.
bool SxDocument::apply_graph_edit(const std::string& label,
                                  const std::function<bool()>& mutate) {
    nlohmann::json before = doc_->graph().to_json();
    if (!mutate()) return false;
    nlohmann::json after = doc_->graph().to_json();
    std::string err;
    if (!doc_->graph().regenerate(*doc_, &err)) {
        sx::log::error(label + ": " + err);
        doc_->set_graph(sx::FeatureGraph::from_json(before));
        doc_->graph().regenerate(*doc_, nullptr);
        return false;
    }
    stack_.push(*doc_, std::make_unique<sx::GraphSnapshotCommand>(label, std::move(before),
                                                                  std::move(after)));
    return true;
}

String SxDocument::graph_add_primitive(const String& kind, double a, double b, double c,
                                       const Vector3& origin) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("add " + to_std(kind), [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Primitive;
        f.params = {{"kind", to_std(kind)}, {"a", a}, {"b", b}, {"c", c},
                    {"origin", {origin.x, origin.y, origin.z}}};
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_sketch(const Ref<SxSketch>& sketch) {
    if (sketch.is_null()) return {};
    sx::EntityId fid;
    bool ok = apply_graph_edit("add sketch", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Sketch;
        f.sketch = sketch->sketch();
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_extrude(const String& sketch_fid, double distance,
                                     bool symmetric, const String& op,
                                     const String& target_fid) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("extrude", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Extrude;
        f.params = {{"sketch", to_std(sketch_fid)}, {"distance", distance},
                    {"symmetric", symmetric}, {"op", to_std(op)}};
        if (!target_fid.is_empty()) f.params["target"] = to_std(target_fid);
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

String SxDocument::graph_add_revolve(const String& sketch_fid, const Vector2& axis_point,
                                     const Vector2& axis_dir, double angle, const String& op,
                                     const String& target_fid) {
    sx::EntityId fid;
    bool ok = apply_graph_edit("revolve", [&] {
        sx::Feature f;
        f.type = sx::FeatureType::Revolve;
        f.params = {{"sketch", to_std(sketch_fid)},
                    {"axis_point", {axis_point.x, axis_point.y}},
                    {"axis_dir", {axis_dir.x, axis_dir.y}},
                    {"angle", angle},
                    {"op", to_std(op)}};
        if (!target_fid.is_empty()) f.params["target"] = to_std(target_fid);
        fid = doc_->graph().add(std::move(f));
        return true;
    });
    return ok ? to_gd(fid.str()) : String();
}

bool SxDocument::graph_set_params(const String& fid, const String& params_json) {
    nlohmann::json p;
    try {
        p = nlohmann::json::parse(to_std(params_json));
    } catch (...) {
        return false;
    }
    return apply_graph_edit("edit feature", [&] {
        return doc_->graph().set_params(parse_id(fid), std::move(p));
    });
}

bool SxDocument::graph_set_suppressed(const String& fid, bool suppressed) {
    return apply_graph_edit(suppressed ? "suppress feature" : "unsuppress feature", [&] {
        return doc_->graph().set_suppressed(parse_id(fid), suppressed);
    });
}

bool SxDocument::graph_remove(const String& fid) {
    return apply_graph_edit("delete feature", [&] {
        return doc_->graph().remove(parse_id(fid));
    });
}

Dictionary SxDocument::graph_regenerate() {
    Dictionary out;
    std::string err;
    bool ok = doc_->graph().regenerate(*doc_, &err);
    out["ok"] = ok;
    out["error"] = to_gd(err);
    return out;
}

bool SxDocument::save(const String& path) {
    std::string err;
    bool ok = sx::save_sxp(*doc_, to_std(path), &err);
    if (!ok) sx::log::error("save failed: " + err);
    return ok;
}

bool SxDocument::load(const String& path) {
    std::string err;
    bool ok = sx::load_sxp(*doc_, to_std(path), &err);
    if (!ok) sx::log::error("load failed: " + err);
    return ok;
}

void SxDocument::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_box", "dx", "dy", "dz", "origin"), &SxDocument::add_box);
    ClassDB::bind_method(D_METHOD("add_cylinder", "radius", "height", "origin"), &SxDocument::add_cylinder);
    ClassDB::bind_method(D_METHOD("add_sphere", "radius", "origin"), &SxDocument::add_sphere);
    ClassDB::bind_method(D_METHOD("add_cone", "r1", "r2", "height", "origin"), &SxDocument::add_cone);
    ClassDB::bind_method(D_METHOD("add_torus", "major_r", "minor_r", "origin"), &SxDocument::add_torus);
    ClassDB::bind_method(D_METHOD("extrude_sketch", "sketch", "distance", "symmetric"), &SxDocument::extrude_sketch);
    ClassDB::bind_method(D_METHOD("revolve_sketch", "sketch", "axis_point", "axis_dir", "angle"), &SxDocument::revolve_sketch);
    ClassDB::bind_method(D_METHOD("delete_body", "body_id"), &SxDocument::delete_body);
    ClassDB::bind_method(D_METHOD("translate_body", "body_id", "delta"), &SxDocument::translate_body);
    ClassDB::bind_method(D_METHOD("push_pull", "face_id", "distance"), &SxDocument::push_pull);
    ClassDB::bind_method(D_METHOD("boolean_op", "target_body", "tool_body", "op", "keep_tool"), &SxDocument::boolean_op);
    ClassDB::bind_method(D_METHOD("fillet_edges", "edge_ids", "radius"), &SxDocument::fillet_edges);
    ClassDB::bind_method(D_METHOD("chamfer_edges", "edge_ids", "distance"), &SxDocument::chamfer_edges);
    ClassDB::bind_method(D_METHOD("mirror_body", "body_id", "plane_point", "plane_normal", "keep_original"), &SxDocument::mirror_body);
    ClassDB::bind_method(D_METHOD("linear_pattern", "body_id", "direction", "spacing", "count"), &SxDocument::linear_pattern);
    ClassDB::bind_method(D_METHOD("circular_pattern", "body_id", "axis_point", "axis_dir", "count", "total_angle"), &SxDocument::circular_pattern);
    ClassDB::bind_method(D_METHOD("rotate_body", "body_id", "axis_point", "axis_dir", "angle"), &SxDocument::rotate_body);
    ClassDB::bind_method(D_METHOD("shell_body", "faces_to_remove", "thickness"), &SxDocument::shell_body);
    ClassDB::bind_method(D_METHOD("offset_body", "body_id", "offset"), &SxDocument::offset_body);
    ClassDB::bind_method(D_METHOD("measure_distance", "a", "b"), &SxDocument::measure_distance);
    ClassDB::bind_method(D_METHOD("measure_bbox", "id"), &SxDocument::measure_bbox);
    ClassDB::bind_method(D_METHOD("measure_mass", "body_id"), &SxDocument::measure_mass);
    ClassDB::bind_method(D_METHOD("measure_edge_length", "edge_id"), &SxDocument::measure_edge_length);
    ClassDB::bind_method(D_METHOD("measure_face_area", "face_id"), &SxDocument::measure_face_area);
    ClassDB::bind_method(D_METHOD("measure_face_angle", "f1", "f2"), &SxDocument::measure_face_angle);
    ClassDB::bind_method(D_METHOD("export_step", "path"), &SxDocument::export_step);
    ClassDB::bind_method(D_METHOD("export_stl", "path", "binary"), &SxDocument::export_stl);
    ClassDB::bind_method(D_METHOD("import_step", "path"), &SxDocument::import_step);
    ClassDB::bind_method(D_METHOD("get_edge_ids", "body_id"), &SxDocument::get_edge_ids);
    ClassDB::bind_method(D_METHOD("undo"), &SxDocument::undo);
    ClassDB::bind_method(D_METHOD("redo"), &SxDocument::redo);
    ClassDB::bind_method(D_METHOD("can_undo"), &SxDocument::can_undo);
    ClassDB::bind_method(D_METHOD("can_redo"), &SxDocument::can_redo);
    ClassDB::bind_method(D_METHOD("body_ids"), &SxDocument::body_ids);
    ClassDB::bind_method(D_METHOD("body_name", "body_id"), &SxDocument::body_name);
    ClassDB::bind_method(D_METHOD("body_volume", "body_id"), &SxDocument::body_volume);
    ClassDB::bind_method(D_METHOD("revision"), &SxDocument::revision);
    ClassDB::bind_method(D_METHOD("get_mesh", "body_id"), &SxDocument::get_mesh);
    ClassDB::bind_method(D_METHOD("get_face_ids", "body_id"), &SxDocument::get_face_ids);
    ClassDB::bind_method(D_METHOD("get_edge_lines", "body_id"), &SxDocument::get_edge_lines);
    ClassDB::bind_method(D_METHOD("pick", "origin", "direction"), &SxDocument::pick);
    ClassDB::bind_method(D_METHOD("card_markdown", "entity_id"), &SxDocument::card_markdown);
    ClassDB::bind_method(D_METHOD("set_card_alias", "entity_id", "text"), &SxDocument::set_card_alias);
    ClassDB::bind_method(D_METHOD("set_card_notes", "entity_id", "text"), &SxDocument::set_card_notes);
    ClassDB::bind_method(D_METHOD("graph_features"), &SxDocument::graph_features);
    ClassDB::bind_method(D_METHOD("graph_add_primitive", "kind", "a", "b", "c", "origin"), &SxDocument::graph_add_primitive);
    ClassDB::bind_method(D_METHOD("graph_add_sketch", "sketch"), &SxDocument::graph_add_sketch);
    ClassDB::bind_method(D_METHOD("graph_add_extrude", "sketch_fid", "distance", "symmetric", "op", "target_fid"), &SxDocument::graph_add_extrude);
    ClassDB::bind_method(D_METHOD("graph_add_revolve", "sketch_fid", "axis_point", "axis_dir", "angle", "op", "target_fid"), &SxDocument::graph_add_revolve);
    ClassDB::bind_method(D_METHOD("graph_set_params", "fid", "params_json"), &SxDocument::graph_set_params);
    ClassDB::bind_method(D_METHOD("graph_set_suppressed", "fid", "suppressed"), &SxDocument::graph_set_suppressed);
    ClassDB::bind_method(D_METHOD("graph_remove", "fid"), &SxDocument::graph_remove);
    ClassDB::bind_method(D_METHOD("graph_regenerate"), &SxDocument::graph_regenerate);
    ClassDB::bind_method(D_METHOD("save", "path"), &SxDocument::save);
    ClassDB::bind_method(D_METHOD("load", "path"), &SxDocument::load);
}

}  // namespace sx_godot
