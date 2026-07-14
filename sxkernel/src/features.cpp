#include "sx/features.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <stdexcept>

#include "sx/document.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch_json.hpp"

using nlohmann::json;

namespace sx {

const char* to_string(FeatureType t) {
    switch (t) {
        case FeatureType::Primitive: return "primitive";
        case FeatureType::Sketch: return "sketch";
        case FeatureType::Extrude: return "extrude";
        case FeatureType::Revolve: return "revolve";
        case FeatureType::Boolean: return "boolean";
        case FeatureType::Fillet: return "fillet";
        case FeatureType::Chamfer: return "chamfer";
        case FeatureType::Mirror: return "mirror";
        case FeatureType::LinearPattern: return "linear_pattern";
        case FeatureType::CircularPattern: return "circular_pattern";
        case FeatureType::Shell: return "shell";
        case FeatureType::Offset: return "offset";
    }
    return "unknown";
}

FeatureType feature_type_from_string(const std::string& s) {
    if (s == "primitive") return FeatureType::Primitive;
    if (s == "sketch") return FeatureType::Sketch;
    if (s == "extrude") return FeatureType::Extrude;
    if (s == "revolve") return FeatureType::Revolve;
    if (s == "boolean") return FeatureType::Boolean;
    if (s == "fillet") return FeatureType::Fillet;
    if (s == "chamfer") return FeatureType::Chamfer;
    if (s == "mirror") return FeatureType::Mirror;
    if (s == "linear_pattern") return FeatureType::LinearPattern;
    if (s == "circular_pattern") return FeatureType::CircularPattern;
    if (s == "shell") return FeatureType::Shell;
    if (s == "offset") return FeatureType::Offset;
    throw std::invalid_argument("unknown feature type: " + s);
}

static bool creates_body(const Feature& f) {
    if (f.type == FeatureType::Primitive || f.type == FeatureType::Mirror) return true;
    if (f.type == FeatureType::Extrude || f.type == FeatureType::Revolve)
        return f.params.value("op", "new") == "new";
    return false;
}

EntityId FeatureGraph::add(Feature f) {
    if (f.id.is_null()) f.id = EntityId::generate();
    if (f.name.empty())
        f.name = std::string(to_string(f.type)) + " " + std::to_string(timeline_.size() + 1);
    if (creates_body(f) && f.output_body.is_null()) f.output_body = EntityId::generate();
    EntityId id = f.id;
    timeline_.push_back(std::move(f));
    return id;
}

bool FeatureGraph::remove(const EntityId& id) {
    if (has_dependents(id)) return false;
    for (auto it = timeline_.begin(); it != timeline_.end(); ++it) {
        if (it->id == id) {
            timeline_.erase(it);
            return true;
        }
    }
    return false;
}

bool FeatureGraph::set_suppressed(const EntityId& id, bool suppressed) {
    Feature* f = feature(id);
    if (!f) return false;
    f->suppressed = suppressed;
    return true;
}

bool FeatureGraph::set_params(const EntityId& id, json params) {
    Feature* f = feature(id);
    if (!f) return false;
    f->params = std::move(params);
    return true;
}

Feature* FeatureGraph::feature(const EntityId& id) {
    for (auto& f : timeline_)
        if (f.id == id) return &f;
    return nullptr;
}

const Feature* FeatureGraph::feature(const EntityId& id) const {
    for (const auto& f : timeline_)
        if (f.id == id) return &f;
    return nullptr;
}

bool FeatureGraph::has_dependents(const EntityId& id) const {
    std::string needle = id.str();
    bool found_self = false;
    for (const auto& f : timeline_) {
        if (f.id == id) {
            found_self = true;
            continue;
        }
        if (!found_self) continue;
        for (const char* key : {"sketch", "target", "tool"}) {
            if (f.params.contains(key) && f.params[key].get<std::string>() == needle)
                return true;
        }
    }
    return false;
}

// --- regeneration ---

namespace {
shape::Placement placement_from(const json& p) {
    shape::Placement pl;
    if (p.contains("origin"))
        for (int i = 0; i < 3; ++i) pl.origin[i] = p["origin"][i].get<double>();
    return pl;
}

TopoDS_Shape build_primitive_feature(const json& p) {
    std::string kind = p.value("kind", "box");
    double a = p.value("a", 10.0), b = p.value("b", 10.0), c = p.value("c", 10.0);
    auto pl = placement_from(p);
    if (kind == "box") return shape::make_box(a, b, c, pl);
    if (kind == "cylinder") return shape::make_cylinder(a, b, pl);
    if (kind == "sphere") return shape::make_sphere(a, pl);
    if (kind == "cone") return shape::make_cone(a, b, c, pl);
    if (kind == "torus") return shape::make_torus(a, b, pl);
    throw std::runtime_error("unknown primitive kind: " + kind);
}

gp_Pnt pnt_from(const json& a) {
    return gp_Pnt(a[0].get<double>(), a[1].get<double>(), a[2].get<double>());
}

gp_Dir dir_from(const json& a) {
    double x = a[0].get<double>(), y = a[1].get<double>(), z = a[2].get<double>();
    double len = std::sqrt(x * x + y * y + z * z);
    if (len < 1e-15) throw std::runtime_error("zero-length direction");
    return gp_Dir(x / len, y / len, z / len);
}

void ensure_pattern_slots(Feature& f, int count, Document& doc) {
    if (count < 2) throw std::runtime_error("pattern count must be >= 2");
    const size_t needed = static_cast<size_t>(count - 1);
    if (f.output_bodies.size() > needed) {
        for (size_t i = needed; i < f.output_bodies.size(); ++i) {
            if (doc.body(f.output_bodies[i])) doc.remove_body(f.output_bodies[i]);
        }
        f.output_bodies.resize(needed);
    } else {
        while (f.output_bodies.size() < needed) f.output_bodies.push_back(EntityId::generate());
    }
}

void put_body(Document& doc, const EntityId& id, const TopoDS_Shape& shape,
              const std::string& name) {
    if (doc.body(id)) doc.replace_body_shape(id, shape);
    else doc.add_body(shape, name, id);
}
}  // namespace

bool FeatureGraph::apply(Document& doc, Feature& f, std::string* err) {
    auto fail = [&](const std::string& msg) {
        if (err) *err = f.name + ": " + msg;
        return false;
    };
    auto find_feature_body = [&](const std::string& key) -> EntityId {
        if (!f.params.contains(key)) return {};
        const Feature* ref = feature(EntityId::from_string(f.params[key].get<std::string>()));
        return ref ? ref->output_body : EntityId{};
    };

    try {
        switch (f.type) {
            case FeatureType::Sketch:
                return true;  // no geometry output

            case FeatureType::Primitive: {
                TopoDS_Shape shape = build_primitive_feature(f.params);
                // Rebuilding into a live body routes through replace_body_shape,
                // which runs the naming service so subshape ids survive edits.
                put_body(doc, f.output_body, shape, f.name);
                return true;
            }

            case FeatureType::Extrude:
            case FeatureType::Revolve: {
                EntityId sketch_fid = EntityId::from_string(f.params.at("sketch").get<std::string>());
                const Feature* skf = feature(sketch_fid);
                if (!skf || !skf->sketch) return fail("missing sketch feature");
                std::string perr;
                TopoDS_Shape face = skf->sketch->profile_face(&perr);
                if (face.IsNull()) return fail("profile: " + perr);

                TopoDS_Shape result;
                if (f.type == FeatureType::Extrude) {
                    auto n = skf->sketch->plane().normal();
                    gp_Vec dir(n[0], n[1], n[2]);
                    dir.Normalize();
                    double dist = f.params.value("distance", 10.0);
                    TopoDS_Shape profile = face;
                    if (f.params.value("symmetric", false)) {
                        gp_Trsf t;
                        t.SetTranslation(dir * (-dist / 2.0));
                        profile = BRepBuilderAPI_Transform(face, t, true).Shape();
                    }
                    result = BRepPrimAPI_MakePrism(profile, dir * dist).Shape();
                } else {
                    const auto& pl = skf->sketch->plane();
                    auto at = [&](double u, double v) {
                        return gp_Pnt(pl.origin[0] + pl.x_dir[0] * u + pl.y_dir[0] * v,
                                      pl.origin[1] + pl.x_dir[1] * u + pl.y_dir[1] * v,
                                      pl.origin[2] + pl.x_dir[2] * u + pl.y_dir[2] * v);
                    };
                    auto ap = f.params.at("axis_point");
                    auto ad = f.params.at("axis_dir");
                    gp_Pnt p0 = at(ap[0].get<double>(), ap[1].get<double>());
                    gp_Pnt p1 = at(ap[0].get<double>() + ad[0].get<double>(),
                                   ap[1].get<double>() + ad[1].get<double>());
                    result = BRepPrimAPI_MakeRevol(face, gp_Ax1(p0, gp_Dir(gp_Vec(p0, p1))),
                                                   f.params.value("angle", 6.283185307179586))
                                 .Shape();
                }
                if (result.IsNull()) return fail("geometry generation failed");

                std::string op = f.params.value("op", "new");
                if (op == "new") {
                    put_body(doc, f.output_body, result, f.name);
                } else {
                    EntityId target = find_feature_body("target");
                    const Body* tb = doc.body(target);
                    if (!tb) return fail("missing target body");
                    TopoDS_Shape merged = (op == "cut")
                                              ? TopoDS_Shape(BRepAlgoAPI_Cut(tb->shape, result).Shape())
                                              : TopoDS_Shape(BRepAlgoAPI_Fuse(tb->shape, result).Shape());
                    if (merged.IsNull()) return fail("boolean failed");
                    doc.replace_body_shape(target, merged);
                }
                return true;
            }

            case FeatureType::Boolean: {
                EntityId target = find_feature_body("target");
                EntityId tool = find_feature_body("tool");
                const Body* tb = doc.body(target);
                const Body* ob = doc.body(tool);
                if (!tb || !ob) return fail("missing boolean operand body");
                std::string op = f.params.value("op", "fuse");
                TopoDS_Shape result;
                if (op == "fuse") result = BRepAlgoAPI_Fuse(tb->shape, ob->shape).Shape();
                else if (op == "cut") result = BRepAlgoAPI_Cut(tb->shape, ob->shape).Shape();
                else result = BRepAlgoAPI_Common(tb->shape, ob->shape).Shape();
                if (result.IsNull()) return fail("boolean failed");
                doc.replace_body_shape(target, result);
                doc.remove_body(tool);
                return true;
            }

            case FeatureType::Fillet:
            case FeatureType::Chamfer: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                TopTools_IndexedMapOfShape edges;
                TopExp::MapShapes(tb->shape, TopAbs_EDGE, edges);
                double v = f.params.value(f.type == FeatureType::Fillet ? "radius" : "distance", 1.0);

                TopoDS_Shape result;
                if (f.type == FeatureType::Fillet) {
                    BRepFilletAPI_MakeFillet mk(tb->shape);
                    for (const auto& je : f.params.at("edges")) {
                        int idx = je.get<int>();
                        if (idx < 1 || idx > edges.Extent()) return fail("edge index out of range");
                        mk.Add(v, TopoDS::Edge(edges(idx)));
                    }
                    mk.Build();
                    if (!mk.IsDone()) return fail("fillet failed");
                    result = mk.Shape();
                } else {
                    BRepFilletAPI_MakeChamfer mk(tb->shape);
                    for (const auto& je : f.params.at("edges")) {
                        int idx = je.get<int>();
                        if (idx < 1 || idx > edges.Extent()) return fail("edge index out of range");
                        mk.Add(v, TopoDS::Edge(edges(idx)));
                    }
                    mk.Build();
                    if (!mk.IsDone()) return fail("chamfer failed");
                    result = mk.Shape();
                }
                if (!shape::is_valid(result)) return fail("result invalid");
                doc.replace_body_shape(target, result);
                return true;
            }

            case FeatureType::Mirror: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                gp_Trsf t;
                t.SetMirror(gp_Ax2(pnt_from(f.params.at("plane_point")),
                                   dir_from(f.params.at("plane_normal"))));
                TopoDS_Shape mirrored =
                    BRepBuilderAPI_Transform(tb->shape, t, /*copy=*/true).Shape();
                if (mirrored.IsNull() || !shape::is_valid(mirrored))
                    return fail("mirror failed");
                put_body(doc, f.output_body, mirrored, "Mirror of " + tb->name);
                return true;
            }

            case FeatureType::LinearPattern: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                int count = f.params.value("count", 0);
                double spacing = f.params.value("spacing", 0.0);
                ensure_pattern_slots(f, count, doc);
                gp_Dir dir = dir_from(f.params.at("direction"));
                for (int i = 1; i < count; ++i) {
                    gp_Trsf t;
                    t.SetTranslation(gp_Vec(dir.XYZ() * (spacing * i)));
                    TopoDS_Shape copy =
                        BRepBuilderAPI_Transform(tb->shape, t, /*copy=*/true).Shape();
                    if (copy.IsNull() || !shape::is_valid(copy))
                        return fail("linear pattern failed");
                    const std::string name = tb->name + " [" + std::to_string(i + 1) + "]";
                    put_body(doc, f.output_bodies[static_cast<size_t>(i - 1)], copy, name);
                }
                return true;
            }

            case FeatureType::CircularPattern: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                int count = f.params.value("count", 0);
                ensure_pattern_slots(f, count, doc);
                gp_Ax1 axis(pnt_from(f.params.at("axis_point")),
                           dir_from(f.params.at("axis_dir")));
                double total = f.params.value("total_angle", 2.0 * M_PI);
                double step = total / static_cast<double>(count);
                for (int i = 1; i < count; ++i) {
                    gp_Trsf t;
                    t.SetRotation(axis, step * i);
                    TopoDS_Shape copy =
                        BRepBuilderAPI_Transform(tb->shape, t, /*copy=*/true).Shape();
                    if (copy.IsNull() || !shape::is_valid(copy))
                        return fail("circular pattern failed");
                    const std::string name = tb->name + " [" + std::to_string(i + 1) + "]";
                    put_body(doc, f.output_bodies[static_cast<size_t>(i - 1)], copy, name);
                }
                return true;
            }

            case FeatureType::Shell: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                TopTools_IndexedMapOfShape faces;
                TopExp::MapShapes(tb->shape, TopAbs_FACE, faces);
                TopTools_ListOfShape remove_faces;
                for (const auto& jf : f.params.at("faces")) {
                    int idx = jf.get<int>();
                    if (idx < 1 || idx > faces.Extent()) return fail("face index out of range");
                    remove_faces.Append(faces(idx));
                }
                if (remove_faces.IsEmpty()) return fail("no faces to remove");
                double thickness = f.params.value("thickness", 1.0);
                BRepOffsetAPI_MakeThickSolid mk;
                mk.MakeThickSolidByJoin(tb->shape, remove_faces, -thickness, 1e-3);
                if (!mk.IsDone()) return fail("shell failed");
                TopoDS_Shape result = mk.Shape();
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("shell result invalid");
                doc.replace_body_shape(target, result);
                return true;
            }

            case FeatureType::Offset: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                double offset = f.params.value("offset", 0.0);
                BRepOffsetAPI_MakeOffsetShape mk;
                mk.PerformByJoin(tb->shape, offset, 1e-3);
                if (!mk.IsDone()) return fail("offset failed");
                TopoDS_Shape result = mk.Shape();
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("offset result invalid");
                doc.replace_body_shape(target, result);
                return true;
            }
        }
    } catch (const std::exception& e) {
        return fail(e.what());
    }
    return fail("unhandled feature type");
}

bool FeatureGraph::regenerate(Document& doc, std::string* err) {
    // Bodies this pass will rebuild stay in the document so apply() can route
    // through replace_body_shape and the naming service keeps subshape ids
    // (and their cards) stable. Bodies whose features are gone or suppressed
    // are removed up front; generated_ covers features removed from the
    // timeline since the last regenerate.
    std::vector<EntityId> rebuilt;
    for (const auto& f : timeline_) {
        if (f.suppressed) continue;
        if (!f.output_body.is_null()) rebuilt.push_back(f.output_body);
        for (const auto& id : f.output_bodies) rebuilt.push_back(id);
    }
    auto will_rebuild = [&](const EntityId& id) {
        for (const auto& r : rebuilt)
            if (r == id) return true;
        return false;
    };
    for (const auto& id : generated_) {
        if (!will_rebuild(id) && doc.body(id)) doc.remove_body(id);
    }
    for (const auto& f : timeline_) {
        if (!f.output_body.is_null() && !will_rebuild(f.output_body) && doc.body(f.output_body))
            doc.remove_body(f.output_body);
        for (const auto& id : f.output_bodies) {
            if (!will_rebuild(id) && doc.body(id)) doc.remove_body(id);
        }
    }
    generated_.clear();
    for (auto& f : timeline_) {
        if (f.suppressed) continue;
        if (!apply(doc, f, err)) {
            log::error("regenerate stopped at feature " + f.name);
            // Stale bodies of features after the failure point would show the
            // previous generation's geometry; drop them.
            bool past_failure = false;
            for (const auto& g : timeline_) {
                if (g.id == f.id) past_failure = true;
                if (!past_failure) continue;
                if (!g.output_body.is_null() && doc.body(g.output_body))
                    doc.remove_body(g.output_body);
                for (const auto& id : g.output_bodies) {
                    if (doc.body(id)) doc.remove_body(id);
                }
            }
            return false;
        }
        if (!f.output_body.is_null()) generated_.push_back(f.output_body);
        for (const auto& id : f.output_bodies) generated_.push_back(id);
    }
    return true;
}

// --- persistence ---

json FeatureGraph::to_json() const {
    json j;
    j["timeline"] = json::array();
    for (const auto& f : timeline_) {
        json jf;
        jf["id"] = f.id.str();
        jf["name"] = f.name;
        jf["type"] = to_string(f.type);
        jf["suppressed"] = f.suppressed;
        jf["params"] = f.params;
        if (!f.output_body.is_null()) jf["output_body"] = f.output_body.str();
        if (!f.output_bodies.empty()) {
            jf["output_bodies"] = json::array();
            for (const auto& id : f.output_bodies) jf["output_bodies"].push_back(id.str());
        }
        if (f.sketch) jf["sketch_data"] = sketch_to_json(*f.sketch);
        j["timeline"].push_back(jf);
    }
    return j;
}

FeatureGraph FeatureGraph::from_json(const json& j) {
    FeatureGraph g;
    for (const auto& jf : j.at("timeline")) {
        Feature f;
        f.id = EntityId::from_string(jf.at("id").get<std::string>());
        f.name = jf.value("name", "feature");
        f.type = feature_type_from_string(jf.at("type").get<std::string>());
        f.suppressed = jf.value("suppressed", false);
        f.params = jf.value("params", json::object());
        if (jf.contains("output_body"))
            f.output_body = EntityId::from_string(jf["output_body"].get<std::string>());
        if (jf.contains("output_bodies")) {
            for (const auto& s : jf["output_bodies"])
                f.output_bodies.push_back(EntityId::from_string(s.get<std::string>()));
        }
        if (jf.contains("sketch_data")) f.sketch = sketch_from_json(jf["sketch_data"]);
        g.timeline_.push_back(std::move(f));
    }
    return g;
}

}  // namespace sx
