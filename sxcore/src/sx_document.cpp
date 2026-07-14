#include "sx_document.hpp"

#include <godot_cpp/core/class_db.hpp>

#include "sx/commands_sketch.hpp"
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
    ClassDB::bind_method(D_METHOD("save", "path"), &SxDocument::save);
    ClassDB::bind_method(D_METHOD("load", "path"), &SxDocument::load);
}

}  // namespace sx_godot
