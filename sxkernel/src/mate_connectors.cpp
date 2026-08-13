#include "sx/mate_connectors.hpp"

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Vec.hxx>

#include <cmath>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/log.hpp"
#include "sx/mates.hpp"

namespace sx {

namespace {

gp_Pnt face_center(const TopoDS_Shape& face) {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face, props);
    return props.CentreOfMass();
}

void append_body_connectors(const Document& doc, const EntityId& body_id,
                            const EntityId& instance_id,
                            std::vector<MateConnector>& out) {
    const Body* b = doc.body(body_id);
    if (!b) return;
    auto it = b->subshape_ids.find(EntityKind::Face);
    if (it == b->subshape_ids.end()) return;
    for (const auto& fid : it->second) {
        if (auto pl = mate_plane(doc, instance_id, fid)) {
            MateConnector c;
            c.face = fid;
            c.instance = instance_id;
            c.body = body_id;
            c.kind = ConnectorKind::Planar;
            c.origin = pl->point;
            // Prefer surface COM projected onto the plane for a stable origin.
            TopoDS_Shape sh = doc.resolve(fid);
            if (!sh.IsNull() && sh.ShapeType() == TopAbs_FACE) {
                gp_Pnt com = face_center(sh);
                if (!instance_id.is_null()) {
                    const Instance* inst = doc.instance(instance_id);
                    if (inst) com.Transform(transform_of(*inst));
                }
                double h = gp_Vec(pl->point, com).Dot(gp_Vec(pl->normal));
                c.origin = com.Translated(gp_Vec(pl->normal) * (-h));
            }
            c.z_axis = pl->normal;
            out.push_back(c);
            continue;
        }
        if (auto cyl = mate_cylinder(doc, instance_id, fid)) {
            MateConnector c;
            c.face = fid;
            c.instance = instance_id;
            c.body = body_id;
            c.kind = ConnectorKind::Cylindrical;
            c.origin = cyl->point;
            c.z_axis = cyl->dir;
            c.radius = cyl->radius;
            out.push_back(c);
        }
    }
}

bool compatible(const MateConnector& a, const MateConnector& b) {
    return a.kind == b.kind;
}

MateType mate_for(ConnectorKind k) {
    return k == ConnectorKind::Cylindrical ? MateType::Concentric
                                          : MateType::PlaneCoincident;
}

}  // namespace

std::vector<MateConnector> implicit_connectors(const Document& doc) {
    std::vector<MateConnector> out;
    // Grounded bodies (shown as sources even if also instanced).
    for (const auto& bid : doc.body_ids()) {
        append_body_connectors(doc, bid, {}, out);
    }
    for (const auto& inst : doc.instances()) {
        append_body_connectors(doc, inst.source_body, inst.id, out);
    }
    return out;
}

std::optional<ConnectorSnap> find_connector_snap(const Document& doc,
                                                 const EntityId& moving_instance,
                                                 double max_dist) {
    if (moving_instance.is_null() || !doc.instance(moving_instance)) return std::nullopt;
    auto all = implicit_connectors(doc);
    std::vector<const MateConnector*> moving;
    std::vector<const MateConnector*> targets;
    for (const auto& c : all) {
        if (c.instance == moving_instance) moving.push_back(&c);
        else targets.push_back(&c);
    }
    if (moving.empty() || targets.empty()) return std::nullopt;

    std::optional<ConnectorSnap> best;
    for (const auto* from : moving) {
        for (const auto* to : targets) {
            if (!compatible(*from, *to)) continue;
            // Don't snap a connector to another on the same source body when
            // both are grounded (same body id, both instance null) — still OK
            // for instance→ground of the same source.
            double d = from->origin.Distance(to->origin);
            if (d > max_dist) continue;
            if (best && d >= best->distance) continue;
            ConnectorSnap s;
            s.from = *from;
            s.to = *to;
            s.mate_type = mate_for(from->kind);
            s.distance = d;
            best = s;
        }
    }
    return best;
}

EntityId apply_connector_snap(Document& doc, const ConnectorSnap& snap) {
    Mate m;
    m.type = snap.mate_type;
    // Target is A (stays put); moving instance is B.
    m.instance_a = snap.to.instance;
    m.face_a = snap.to.face;
    m.instance_b = snap.from.instance;
    m.face_b = snap.from.face;
    m.offset = 0.0;
    m.flip = false;
    m.name = std::string("snap ") + to_string(snap.mate_type);
    auto mid = doc.add_mate(std::move(m));
    if (mid.is_null()) return {};
    if (!solve_mates(doc)) {
        log::error("connector snap: mate added but solve failed");
    }
    return mid;
}

}  // namespace sx
