#include "sx/features.hpp"

#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepTools.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cmath>
#include <stdexcept>

#include "sx/curves.hpp"
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
        case FeatureType::Hole: return "hole";
        case FeatureType::Mirror: return "mirror";
        case FeatureType::LinearPattern: return "linear_pattern";
        case FeatureType::CircularPattern: return "circular_pattern";
        case FeatureType::Shell: return "shell";
        case FeatureType::Offset: return "offset";
        case FeatureType::Sweep: return "sweep";
        case FeatureType::Loft: return "loft";
        case FeatureType::HelixSweep: return "helix_sweep";
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
    if (s == "hole") return FeatureType::Hole;
    if (s == "mirror") return FeatureType::Mirror;
    if (s == "linear_pattern") return FeatureType::LinearPattern;
    if (s == "circular_pattern") return FeatureType::CircularPattern;
    if (s == "shell") return FeatureType::Shell;
    if (s == "offset") return FeatureType::Offset;
    if (s == "sweep") return FeatureType::Sweep;
    if (s == "loft") return FeatureType::Loft;
    if (s == "helix_sweep") return FeatureType::HelixSweep;
    throw std::invalid_argument("unknown feature type: " + s);
}

static bool creates_body(const Feature& f) {
    if (f.type == FeatureType::Primitive || f.type == FeatureType::Mirror ||
        f.type == FeatureType::Sweep || f.type == FeatureType::Loft ||
        f.type == FeatureType::HelixSweep)
        return true;
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
        if (f.params.contains("sketches") && f.params["sketches"].is_array()) {
            for (const auto& s : f.params["sketches"]) {
                if (s.is_string() && s.get<std::string>() == needle) return true;
            }
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

TopoDS_Shape build_primitive_feature(const json& p,
                                      const std::map<std::string, double>& env) {
    std::string kind = p.value("kind", "box");
    double a = num_param(p, "a", 10.0, env), b = num_param(p, "b", 10.0, env),
           c = num_param(p, "c", 10.0, env);
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

// Minimal duplicate of HoleCommand tool construction (see commands_hole.cpp).
// Owned-file constraint prevents extracting a shared helper from commands_hole.
constexpr double k_hole_nudge = 1.0;
constexpr double k_hole_through = 1e6;

shape::Placement hole_ax_placement(const gp_Pnt& origin, const gp_Dir& z) {
    shape::Placement p;
    p.origin = {origin.X(), origin.Y(), origin.Z()};
    p.z_dir = {z.X(), z.Y(), z.Z()};
    const gp_Dir ref = (std::abs(z.Dot(gp_Dir(0, 0, 1))) < 0.9) ? gp_Dir(0, 0, 1)
                                                                  : gp_Dir(1, 0, 0);
    const gp_Dir x = z.Crossed(ref);
    p.x_dir = {x.X(), x.Y(), x.Z()};
    return p;
}

TopoDS_Shape build_feature_hole_tool(const gp_Pnt& position, const gp_Dir& direction,
                                     double diameter, double depth, const std::string& type,
                                     double cb_diameter, double cb_depth, double cs_diameter,
                                     double cs_angle_deg) {
    const double radius = diameter * 0.5;
    if (radius <= 0.0 || depth <= 0.0) return {};

    const gp_Pnt origin = position.Translated(gp_Vec(direction) * (-k_hole_nudge));
    const double cyl_h = depth + k_hole_nudge;
    const auto place = hole_ax_placement(origin, direction);

    TopoDS_Shape tool = shape::make_cylinder(radius, cyl_h, place);
    if (tool.IsNull()) return {};

    if (type == "simple") return tool;

    if (type == "counterbore") {
        const double cb_r = cb_diameter * 0.5;
        if (cb_r <= radius || cb_depth <= 0.0) return {};
        TopoDS_Shape cb = shape::make_cylinder(cb_r, cb_depth + k_hole_nudge, place);
        BRepAlgoAPI_Fuse fuse(tool, cb);
        if (!fuse.IsDone()) return {};
        return fuse.Shape();
    }

    if (type == "countersink") {
        const double cs_r = cs_diameter * 0.5;
        const double angle = cs_angle_deg * M_PI / 180.0;
        if (cs_r <= radius || angle <= 0.0 || angle >= M_PI) return {};
        const double half = angle * 0.5;
        const double tan_half = std::tan(half);
        if (tan_half <= 1e-12) return {};
        const double cs_h = (cs_r - radius) / tan_half;
        if (cs_h <= 0.0) return {};
        const double cone_h = cs_h + k_hole_nudge;
        const double r2 = std::max(0.0, cs_r - cone_h * tan_half);
        TopoDS_Shape cone = shape::make_cone(cs_r, r2, cone_h, place);
        BRepAlgoAPI_Fuse fuse(tool, cone);
        if (!fuse.IsDone()) return {};
        return fuse.Shape();
    }
    return {};
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

TopoDS_Wire make_polyline_wire(const json& path) {
    if (!path.is_array() || path.size() < 2)
        throw std::runtime_error("path needs at least two points");
    BRepBuilderAPI_MakeWire mk;
    for (size_t i = 1; i < path.size(); ++i) {
        gp_Pnt a = pnt_from(path[i - 1]);
        gp_Pnt b = pnt_from(path[i]);
        if (a.Distance(b) < 1e-12) throw std::runtime_error("zero-length path segment");
        BRepBuilderAPI_MakeEdge edge(a, b);
        if (!edge.IsDone()) throw std::runtime_error("failed to build path edge");
        mk.Add(edge.Edge());
    }
    if (!mk.IsDone()) throw std::runtime_error("failed to build path wire");
    return mk.Wire();
}

TopoDS_Shape sweep_along_polyline(const TopoDS_Shape& face, const json& path) {
    TopoDS_Wire spine = make_polyline_wire(path);
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(spine, TopAbs_EDGE, edges);
    if (edges.Extent() <= 1) {
        BRepOffsetAPI_MakePipe pipe(spine, face);
        if (!pipe.IsDone()) throw std::runtime_error("MakePipe failed");
        return pipe.Shape();
    }
    TopoDS_Wire profile_wire = BRepTools::OuterWire(TopoDS::Face(face));
    if (profile_wire.IsNull()) throw std::runtime_error("profile has no outer wire");
    BRepOffsetAPI_MakePipeShell shell(spine);
    shell.SetMode();
    shell.SetTransitionMode(BRepBuilderAPI_RightCorner);
    shell.Add(profile_wire, /*withContact=*/Standard_False,
              /*withCorrection=*/Standard_True);
    shell.Build();
    if (!shell.IsDone()) throw std::runtime_error("MakePipeShell failed");
    if (!shell.MakeSolid()) throw std::runtime_error("MakePipeShell could not make solid");
    return shell.Shape();
}

// Pipe a circular profile along a helix spine (spring / thread groundwork).
// Profile placement is analytic (not sampled from the wire):
//   start = axis.Location + radius · XDir  (cylinder UV=(0,0))
//   tangent at θ=0: s·radius·YDir + (pitch/(2π))·ZDir, s=±1 for handedness
// PipeShell Frenet + withCorrection matches the proven curves test config.
TopoDS_Shape helix_sweep_solid(const gp_Ax2& axis, double helix_r, double pitch,
                               double turns, bool left_handed, double profile_r) {
    if (helix_r <= 0.0) throw std::runtime_error("helix radius must be positive");
    if (turns <= 0.0) throw std::runtime_error("helix turns must be positive");
    if (profile_r <= 0.0) throw std::runtime_error("profile_radius must be positive");

    TopoDS_Wire spine = curves::helix(axis, helix_r, pitch, turns, left_handed);

    const gp_Pnt start = axis.Location().Translated(gp_Vec(axis.XDirection()) * helix_r);
    const double sense = left_handed ? -1.0 : 1.0;
    gp_Vec tangent = gp_Vec(axis.YDirection()) * (sense * helix_r) +
                     gp_Vec(axis.Direction()) * (pitch / (2.0 * M_PI));
    if (tangent.Magnitude() < 1e-15) throw std::runtime_error("degenerate helix tangent");

    gp_Circ circ(gp_Ax2(start, gp_Dir(tangent)), profile_r);
    TopoDS_Wire profile =
        BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(circ).Edge()).Wire();

    BRepOffsetAPI_MakePipeShell shell(spine);
    shell.SetMode();  // Frenet
    shell.Add(profile, /*withContact=*/Standard_False,
              /*withCorrection=*/Standard_True);
    shell.Build();
    if (!shell.IsDone()) throw std::runtime_error("MakePipeShell failed");
    if (!shell.MakeSolid()) throw std::runtime_error("MakePipeShell could not make solid");
    return shell.Shape();
}
}  // namespace

bool FeatureGraph::apply(Document& doc, Feature& f,
                         const std::map<std::string, double>& env, std::string* err) {
    auto fail = [&](const std::string& msg) {
        if (err) *err = f.name + ": " + msg;
        return false;
    };

    try {
        // Resolve "=expr" string params to numbers so every double read below
        // (including nested origin/position arrays) sees concrete values.
        const json params = resolve_params(f.params, env);
        auto find_feature_body = [&](const std::string& key) -> EntityId {
            if (!params.contains(key)) return {};
            const Feature* ref =
                feature(EntityId::from_string(params[key].get<std::string>()));
            return ref ? ref->output_body : EntityId{};
        };

        switch (f.type) {
            case FeatureType::Sketch:
                return true;  // no geometry output

            case FeatureType::Primitive: {
                TopoDS_Shape shape = build_primitive_feature(params, env);
                // Rebuilding into a live body routes through replace_body_shape,
                // which runs the naming service so subshape ids survive edits.
                put_body(doc, f.output_body, shape, f.name);
                return true;
            }

            case FeatureType::Extrude:
            case FeatureType::Revolve: {
                EntityId sketch_fid = EntityId::from_string(params.at("sketch").get<std::string>());
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
                    double dist = num_param(params, "distance", 10.0, env);
                    TopoDS_Shape profile = face;
                    if (params.value("symmetric", false)) {
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
                    auto ap = params.at("axis_point");
                    auto ad = params.at("axis_dir");
                    gp_Pnt p0 = at(ap[0].get<double>(), ap[1].get<double>());
                    gp_Pnt p1 = at(ap[0].get<double>() + ad[0].get<double>(),
                                   ap[1].get<double>() + ad[1].get<double>());
                    result = BRepPrimAPI_MakeRevol(face, gp_Ax1(p0, gp_Dir(gp_Vec(p0, p1))),
                                                   num_param(params, "angle", 6.283185307179586, env))
                                 .Shape();
                }
                if (result.IsNull()) return fail("geometry generation failed");

                std::string op = params.value("op", "new");
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
                std::string op = params.value("op", "fuse");
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
                double v = num_param(params,
                                     f.type == FeatureType::Fillet ? "radius" : "distance", 1.0,
                                     env);

                TopoDS_Shape result;
                if (f.type == FeatureType::Fillet) {
                    BRepFilletAPI_MakeFillet mk(tb->shape);
                    for (const auto& je : params.at("edges")) {
                        int idx = je.get<int>();
                        if (idx < 1 || idx > edges.Extent()) return fail("edge index out of range");
                        mk.Add(v, TopoDS::Edge(edges(idx)));
                    }
                    mk.Build();
                    if (!mk.IsDone()) return fail("fillet failed");
                    result = mk.Shape();
                } else {
                    BRepFilletAPI_MakeChamfer mk(tb->shape);
                    for (const auto& je : params.at("edges")) {
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

            case FeatureType::Hole: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                double diameter = num_param(params, "diameter", 0.0, env);
                if (diameter <= 0.0) return fail("invalid diameter");
                double depth_param = num_param(params, "depth", 0.0, env);
                double depth = depth_param > 0.0 ? depth_param : k_hole_through;
                std::string htype = params.value("type", "simple");
                TopoDS_Shape tool = build_feature_hole_tool(
                    pnt_from(params.at("position")), dir_from(params.at("direction")),
                    diameter, depth, htype, num_param(params, "cb_diameter", 0.0, env),
                    num_param(params, "cb_depth", 0.0, env),
                    num_param(params, "cs_diameter", 0.0, env),
                    num_param(params, "cs_angle_deg", 90.0, env));
                if (tool.IsNull() || !shape::is_valid(tool)) return fail("hole tool failed");
                BRepAlgoAPI_Cut cut(tb->shape, tool);
                if (!cut.IsDone()) return fail("hole cut failed");
                TopoDS_Shape result = cut.Shape();
                if (result.IsNull() || !shape::is_valid(result)) return fail("hole result invalid");
                if (shape::count(result).solids < 1 || shape::volume(result) <= 0.0)
                    return fail("hole destroyed the solid");
                doc.replace_body_shape(target, result);
                return true;
            }

            case FeatureType::Mirror: {
                EntityId target = find_feature_body("target");
                const Body* tb = doc.body(target);
                if (!tb) return fail("missing target body");
                gp_Trsf t;
                t.SetMirror(gp_Ax2(pnt_from(params.at("plane_point")),
                                   dir_from(params.at("plane_normal"))));
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
                int count = params.value("count", 0);
                double spacing = num_param(params, "spacing", 0.0, env);
                ensure_pattern_slots(f, count, doc);
                gp_Dir dir = dir_from(params.at("direction"));
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
                int count = params.value("count", 0);
                ensure_pattern_slots(f, count, doc);
                gp_Ax1 axis(pnt_from(params.at("axis_point")),
                           dir_from(params.at("axis_dir")));
                double total = num_param(params, "total_angle", 2.0 * M_PI, env);
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
                for (const auto& jf : params.at("faces")) {
                    int idx = jf.get<int>();
                    if (idx < 1 || idx > faces.Extent()) return fail("face index out of range");
                    remove_faces.Append(faces(idx));
                }
                if (remove_faces.IsEmpty()) return fail("no faces to remove");
                double thickness = num_param(params, "thickness", 1.0, env);
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
                double offset = num_param(params, "offset", 0.0, env);
                BRepOffsetAPI_MakeOffsetShape mk;
                mk.PerformByJoin(tb->shape, offset, 1e-3);
                if (!mk.IsDone()) return fail("offset failed");
                TopoDS_Shape result = mk.Shape();
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("offset result invalid");
                doc.replace_body_shape(target, result);
                return true;
            }

            case FeatureType::Sweep: {
                EntityId sketch_fid =
                    EntityId::from_string(params.at("sketch").get<std::string>());
                const Feature* skf = feature(sketch_fid);
                if (!skf || !skf->sketch) return fail("missing sketch feature");
                std::string perr;
                TopoDS_Shape face = skf->sketch->profile_face(&perr);
                if (face.IsNull()) return fail("profile: " + perr);
                TopoDS_Shape result;
                try {
                    result = sweep_along_polyline(face, params.at("path"));
                } catch (const Standard_Failure& e) {
                    return fail(std::string("sweep failed: ") + e.GetMessageString());
                } catch (const std::runtime_error& e) {
                    return fail(e.what());
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("sweep result invalid");
                if (shape::count(result).solids < 1) return fail("sweep result is not a solid");
                put_body(doc, f.output_body, result, f.name);
                return true;
            }

            case FeatureType::Loft: {
                if (!params.contains("sketches") || !params["sketches"].is_array() ||
                    params["sketches"].size() < 2)
                    return fail("need at least two sketch features");
                bool ruled = params.value("ruled", false);
                BRepOffsetAPI_ThruSections loft(/*isSolid=*/Standard_True, ruled);
                size_t i = 0;
                for (const auto& js : params["sketches"]) {
                    EntityId sketch_fid = EntityId::from_string(js.get<std::string>());
                    const Feature* skf = feature(sketch_fid);
                    if (!skf || !skf->sketch)
                        return fail("missing sketch feature " + std::to_string(i));
                    std::string perr;
                    TopoDS_Shape face_shape = skf->sketch->profile_face(&perr);
                    if (face_shape.IsNull())
                        return fail("profile " + std::to_string(i) + ": " + perr);
                    TopoDS_Wire wire = BRepTools::OuterWire(TopoDS::Face(face_shape));
                    if (wire.IsNull())
                        return fail("profile " + std::to_string(i) + ": no outer wire");
                    loft.AddWire(wire);
                    ++i;
                }
                TopoDS_Shape result;
                try {
                    loft.Build();
                    if (!loft.IsDone()) return fail("ThruSections failed");
                    result = loft.Shape();
                } catch (const Standard_Failure& e) {
                    return fail(std::string("ThruSections failed: ") + e.GetMessageString());
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("loft result invalid");
                if (shape::count(result).solids < 1) return fail("loft result is not a solid");
                put_body(doc, f.output_body, result, f.name);
                return true;
            }

            case FeatureType::HelixSweep: {
                if (!params.contains("axis_point") || !params.contains("axis_dir"))
                    return fail("missing axis_point/axis_dir");
                const double profile_r = num_param(params, "profile_radius", 1.0, env);
                const double radius = num_param(params, "radius", 0.0, env);
                const double pitch = num_param(params, "pitch", 0.0, env);
                const double turns = num_param(params, "turns", 0.0, env);
                const bool left_handed = params.value("left_handed", false);
                gp_Ax2 axis(pnt_from(params.at("axis_point")),
                           dir_from(params.at("axis_dir")));
                TopoDS_Shape result;
                try {
                    result = helix_sweep_solid(axis, radius, pitch, turns, left_handed,
                                               profile_r);
                } catch (const Standard_Failure& e) {
                    return fail(std::string("helix sweep failed: ") + e.GetMessageString());
                } catch (const std::runtime_error& e) {
                    return fail(e.what());
                }
                if (result.IsNull() || !shape::is_valid(result))
                    return fail("helix sweep result invalid");
                if (shape::count(result).solids < 1)
                    return fail("helix sweep result is not a solid");
                put_body(doc, f.output_body, result, f.name);
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
    std::map<std::string, double> env;
    try {
        env = variables_.evaluate();
    } catch (const std::exception& e) {
        if (err) *err = e.what();
        return false;
    }
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
        if (!apply(doc, f, env, err)) {
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
    j["variables"] = variables_.to_json();
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
    if (j.contains("variables")) g.variables_ = VariableTable::from_json(j["variables"]);
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
