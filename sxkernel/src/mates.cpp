#include "sx/mates.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax1.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <stdexcept>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/log.hpp"

namespace sx {

const char* to_string(MateType t) {
    switch (t) {
        case MateType::Fixed: return "fixed";
        case MateType::PlaneCoincident: return "plane_coincident";
        case MateType::PlaneParallel: return "plane_parallel";
        case MateType::Distance: return "distance";
        case MateType::Angle: return "angle";
        case MateType::Perpendicular: return "perpendicular";
        case MateType::Tangent: return "tangent";
        case MateType::Concentric: return "concentric";
    }
    return "unknown";
}

MateType mate_type_from_string(const std::string& s) {
    if (s == "fixed") return MateType::Fixed;
    if (s == "plane_coincident") return MateType::PlaneCoincident;
    if (s == "plane_parallel") return MateType::PlaneParallel;
    if (s == "distance") return MateType::Distance;
    if (s == "angle") return MateType::Angle;
    if (s == "perpendicular") return MateType::Perpendicular;
    if (s == "tangent") return MateType::Tangent;
    if (s == "concentric") return MateType::Concentric;
    throw std::invalid_argument("unknown mate type: " + s);
}

void to_json(nlohmann::json& j, const Mate& m) {
    j = nlohmann::json{
        {"uuid", m.id.str()},
        {"type", to_string(m.type)},
        {"instance_a", m.instance_a.is_null() ? "" : m.instance_a.str()},
        {"face_a", m.face_a.is_null() ? "" : m.face_a.str()},
        {"instance_b", m.instance_b.is_null() ? "" : m.instance_b.str()},
        {"face_b", m.face_b.is_null() ? "" : m.face_b.str()},
        {"offset", m.offset},
        {"flip", m.flip},
        {"name", m.name},
    };
}

static EntityId id_or_null(const std::string& s) {
    return s.empty() ? EntityId{} : EntityId::from_string(s);
}

void from_json(const nlohmann::json& j, Mate& m) {
    m.id = EntityId::from_string(j.at("uuid").get<std::string>());
    m.type = mate_type_from_string(j.at("type").get<std::string>());
    m.instance_a = id_or_null(j.value("instance_a", ""));
    m.face_a = id_or_null(j.value("face_a", ""));
    m.instance_b = id_or_null(j.value("instance_b", ""));
    m.face_b = id_or_null(j.value("face_b", ""));
    m.offset = j.value("offset", 0.0);
    m.flip = j.value("flip", false);
    m.name = j.value("name", "");
}

namespace {

TopoDS_Shape reference_face(const Document& doc, const EntityId& instance,
                            const EntityId& face) {
    TopoDS_Shape f = doc.resolve(face);
    if (f.IsNull() || f.ShapeType() != TopAbs_FACE) return {};
    if (instance.is_null()) return f;
    const Instance* inst = doc.instance(instance);
    if (!inst) return {};
    return f.Moved(TopLoc_Location(transform_of(*inst)));
}

}  // namespace

std::optional<MatePlane> mate_plane(const Document& doc, const EntityId& instance,
                                    const EntityId& face) {
    TopoDS_Shape f = reference_face(doc, instance, face);
    if (f.IsNull()) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(f));
    if (surf.GetType() != GeomAbs_Plane) return std::nullopt;
    gp_Pln pln = surf.Plane();
    gp_Dir n = pln.Axis().Direction();
    if (f.Orientation() == TopAbs_REVERSED) n.Reverse();
    return MatePlane{pln.Location(), n};
}

std::optional<MateAxis> mate_axis(const Document& doc, const EntityId& instance,
                                  const EntityId& face) {
    auto cyl = mate_cylinder(doc, instance, face);
    if (!cyl) return std::nullopt;
    return MateAxis{cyl->point, cyl->dir};
}

std::optional<MateCylinder> mate_cylinder(const Document& doc, const EntityId& instance,
                                          const EntityId& face) {
    TopoDS_Shape f = reference_face(doc, instance, face);
    if (f.IsNull()) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(f));
    if (surf.GetType() != GeomAbs_Cylinder) return std::nullopt;
    gp_Cylinder c = surf.Cylinder();
    gp_Ax1 ax = c.Axis();
    return MateCylinder{ax.Location(), ax.Direction(), c.Radius()};
}

namespace {

gp_Trsf rotation_about(const gp_Pnt& about, const gp_Dir& from, const gp_Dir& to) {
    gp_Trsf out;
    gp_Quaternion q{gp_Vec(from), gp_Vec(to)};
    gp_Trsf rot;
    rot.SetRotation(q);
    gp_Trsf to_origin, back;
    to_origin.SetTranslation(gp_Vec(about.XYZ().Reversed()));
    back.SetTranslation(gp_Vec(about.XYZ()));
    out = back * rot * to_origin;
    return out;
}

bool move_instance(Document& doc, const EntityId& instance_id, const gp_Trsf& correction) {
    const Instance* inst = doc.instance(instance_id);
    if (!inst) return false;
    gp_Trsf t = correction * transform_of(*inst);
    gp_Quaternion q = t.GetRotation();
    gp_XYZ tr = t.TranslationPart();
    return doc.set_instance_transform(instance_id, {tr.X(), tr.Y(), tr.Z()},
                                      {q.X(), q.Y(), q.Z(), q.W()});
}

// PlaneCoincident and Distance share the same closed-form placer: oppose
// (or align) normals, then close the signed gap to `offset` mm.
bool apply_plane_gap(Document& doc, const Mate& m) {
    auto a = mate_plane(doc, m.instance_a, m.face_a);
    auto b = mate_plane(doc, m.instance_b, m.face_b);
    if (!a || !b) {
        log::error("mate " + m.name + ": planar faces required");
        return false;
    }
    gp_Dir target = m.flip ? a->normal : a->normal.Reversed();
    gp_Trsf corr = rotation_about(b->point, b->normal, target);
    double gap = gp_Vec(a->point, b->point).Dot(gp_Vec(a->normal));
    gp_Trsf shift;
    shift.SetTranslation(gp_Vec(a->normal) * (m.offset - gap));
    return move_instance(doc, m.instance_b, shift * corr);
}

bool apply_angle(Document& doc, const Mate& m, double want_deg) {
    auto a = mate_plane(doc, m.instance_a, m.face_a);
    auto b = mate_plane(doc, m.instance_b, m.face_b);
    if (!a || !b) {
        log::error("mate " + m.name + ": planar faces required");
        return false;
    }
    gp_Vec na(a->normal);
    gp_Vec nb(b->normal);
    double want = want_deg * M_PI / 180.0;
    if (m.flip) want = M_PI - want;
    if (want < 0.0) want = 0.0;
    if (want > M_PI) want = M_PI;

    double cur = na.Angle(nb);  // 0..pi
    gp_Vec axis = na.Crossed(nb);
    if (axis.Magnitude() < 1e-9) {
        // Normals parallel / anti-parallel — pick a stable perpendicular.
        axis = na.Crossed(gp_Vec(1, 0, 0));
        if (axis.Magnitude() < 1e-9) axis = na.Crossed(gp_Vec(0, 1, 0));
    }
    axis.Normalize();
    double delta = want - cur;
    if (std::abs(delta) < 1e-12) return true;
    gp_Trsf rot;
    rot.SetRotation(gp_Ax1(b->point, gp_Dir(axis)), delta);
    return move_instance(doc, m.instance_b, rot);
}

bool apply_tangent(Document& doc, const Mate& m) {
    auto pa = mate_plane(doc, m.instance_a, m.face_a);
    auto pb = mate_plane(doc, m.instance_b, m.face_b);
    auto ca = mate_cylinder(doc, m.instance_a, m.face_a);
    auto cb = mate_cylinder(doc, m.instance_b, m.face_b);

    // Plane (A) + cylinder (B): axis ∥ plane, signed distance = ±radius.
    if (pa && cb) {
        gp_Dir target_dir = cb->dir;
        // Project axis onto plane (remove normal component) so it lies parallel.
        gp_Vec d(cb->dir);
        gp_Vec n(pa->normal);
        gp_Vec proj = d - n * d.Dot(n);
        if (proj.Magnitude() < 1e-9) {
            // Axis was normal to plane — pick any in-plane direction.
            gp_Vec x(1, 0, 0);
            if (std::abs(n.Dot(x)) > 0.9) x = gp_Vec(0, 1, 0);
            proj = n.Crossed(x);
        }
        target_dir = gp_Dir(proj);
        gp_Trsf corr = rotation_about(cb->point, cb->dir, target_dir);

        // Evaluate gap after the orientation correction conceptually: the
        // rotation leaves cb->point fixed, so signed distance is unchanged.
        double gap = gp_Vec(pa->point, cb->point).Dot(gp_Vec(pa->normal));
        double want = m.flip ? -cb->radius : cb->radius;
        gp_Trsf shift;
        shift.SetTranslation(gp_Vec(pa->normal) * (want - gap));
        return move_instance(doc, m.instance_b, shift * corr);
    }

    // Cylinder (A) + plane (B): move the planar instance so it touches A.
    if (ca && pb) {
        gp_Dir target_n = ca->dir;  // plane normal ∥ cylinder axis for contact line
        // Prefer keeping the plane facing the cylinder: choose the normal
        // direction that points toward / away based on flip.
        gp_Pnt foot = ca->point;
        // Build a plane normal perpendicular to? For plane–cyl tangent the
        // plane normal should be radial (perpendicular to axis). Use current
        // plane normal projected into the plane ⊥ axis.
        gp_Vec n(pb->normal);
        gp_Vec ax(ca->dir);
        gp_Vec radial = n - ax * n.Dot(ax);
        if (radial.Magnitude() < 1e-9) {
            gp_Vec x(1, 0, 0);
            if (std::abs(ax.Dot(x)) > 0.9) x = gp_Vec(0, 1, 0);
            radial = ax.Crossed(x);
        }
        target_n = gp_Dir(radial);
        if (m.flip) target_n.Reverse();
        gp_Trsf corr = rotation_about(pb->point, pb->normal, target_n);

        // After rotation, translate so plane is at distance radius from axis.
        // Closest point on axis to pb->point:
        gp_Vec v(ca->point, pb->point);
        gp_Vec axial = ax * v.Dot(ax);
        gp_Vec off = v - axial;
        double cur_r = off.Magnitude();
        gp_Dir outward = cur_r > 1e-9 ? gp_Dir(off) : target_n;
        gp_Pnt target_pt = ca->point.Translated(gp_Vec(outward) * ca->radius + axial);
        // Plane passes through target_pt with normal target_n; move pb->point
        // onto that plane along the normal.
        double gap = gp_Vec(target_pt, pb->point).Dot(gp_Vec(target_n));
        gp_Trsf shift;
        shift.SetTranslation(gp_Vec(target_n) * (-gap));
        return move_instance(doc, m.instance_b, shift * corr);
    }

    // Cylinder–cylinder external (or internal if flip) tangent.
    if (ca && cb) {
        gp_Dir target = ca->dir;
        if (gp_Vec(cb->dir).Dot(gp_Vec(target)) < 0.0) target.Reverse();
        gp_Trsf corr = rotation_about(cb->point, cb->dir, target);

        gp_Vec v(cb->point, ca->point);
        gp_Vec axial = gp_Vec(ca->dir) * v.Dot(gp_Vec(ca->dir));
        gp_Vec radial = v - axial;
        double cur = radial.Magnitude();
        double want = m.flip ? std::abs(ca->radius - cb->radius)
                             : (ca->radius + cb->radius);
        gp_Dir outward;
        if (cur > 1e-9) {
            outward = gp_Dir(radial);
        } else {
            gp_Vec x(1, 0, 0);
            if (std::abs(gp_Vec(ca->dir).Dot(x)) > 0.9) x = gp_Vec(0, 1, 0);
            outward = gp_Dir(gp_Vec(ca->dir).Crossed(x));
        }
        // Move B so vector from B to A radial length equals want:
        // A - B_radial = want * outward  => B moves by (cur - want) along outward
        // where outward points from B toward A (radial = A - B projected).
        gp_Trsf shift;
        shift.SetTranslation(gp_Vec(outward) * (cur - want));
        return move_instance(doc, m.instance_b, shift * corr);
    }

    log::error("mate " + m.name + ": tangent needs plane+cylinder or two cylinders");
    return false;
}

}  // namespace

bool apply_mate(Document& doc, const Mate& m) {
    if (m.type == MateType::Fixed) return doc.instance(m.instance_b) != nullptr;
    if (m.instance_b.is_null() || !doc.instance(m.instance_b)) {
        log::error("mate " + m.name + ": instance_b must be a component instance");
        return false;
    }
    if (doc.instance(m.instance_b)->fixed) return true;
    switch (m.type) {
        case MateType::PlaneCoincident:
        case MateType::Distance:
            return apply_plane_gap(doc, m);
        case MateType::PlaneParallel: {
            auto a = mate_plane(doc, m.instance_a, m.face_a);
            auto b = mate_plane(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": planar faces required");
                return false;
            }
            gp_Dir target = a->normal;
            if (gp_Vec(b->normal).Dot(gp_Vec(target)) < 0.0) target.Reverse();
            if (m.flip) target.Reverse();
            gp_Trsf corr = rotation_about(b->point, b->normal, target);
            return move_instance(doc, m.instance_b, corr);
        }
        case MateType::Angle:
            return apply_angle(doc, m, m.offset);
        case MateType::Perpendicular:
            return apply_angle(doc, m, 90.0);
        case MateType::Tangent:
            return apply_tangent(doc, m);
        case MateType::Concentric: {
            auto a = mate_axis(doc, m.instance_a, m.face_a);
            auto b = mate_axis(doc, m.instance_b, m.face_b);
            if (!a || !b) {
                log::error("mate " + m.name + ": cylindrical faces required");
                return false;
            }
            gp_Dir target = a->dir;
            if (gp_Vec(b->dir).Dot(gp_Vec(target)) < 0.0) target.Reverse();
            gp_Trsf corr = rotation_about(b->point, b->dir, target);
            gp_Vec v(b->point, a->point);
            gp_Vec axial = gp_Vec(a->dir) * v.Dot(gp_Vec(a->dir));
            gp_Trsf shift;
            shift.SetTranslation(v - axial);
            return move_instance(doc, m.instance_b, shift * corr);
        }
        case MateType::Fixed:
            break;
    }
    return false;
}

bool solve_mates(Document& doc) {
    bool ok = true;
    for (const auto& m : doc.mates()) ok = apply_mate(doc, m) && ok;
    return ok;
}

}  // namespace sx
