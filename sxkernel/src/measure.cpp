#include "sx/measure.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <Bnd_Box.hxx>
#include <Geom_Surface.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Mat.hxx>
#include <gp_Pnt.hxx>

#include "sx/instances.hpp"

namespace sx::measure {

std::optional<DistanceResult> min_distance(const Document& doc, const EntityId& a,
                                           const EntityId& b) {
    TopoDS_Shape sa = doc.resolve(a);
    TopoDS_Shape sb = doc.resolve(b);
    if (sa.IsNull() || sb.IsNull()) return std::nullopt;

    BRepExtrema_DistShapeShape dist(sa, sb);
    if (!dist.IsDone() || dist.NbSolution() < 1) return std::nullopt;

    gp_Pnt pa = dist.PointOnShape1(1);
    gp_Pnt pb = dist.PointOnShape2(1);
    DistanceResult r;
    r.distance = dist.Value();
    r.point_a = {pa.X(), pa.Y(), pa.Z()};
    r.point_b = {pb.X(), pb.Y(), pb.Z()};
    return r;
}

std::optional<DistanceResult> closest_point(const Document& doc, const EntityId& shape,
                                            const std::array<double, 3>& from) {
    TopoDS_Shape s = doc.resolve(shape);
    if (s.IsNull()) return std::nullopt;

    const gp_Pnt p(from[0], from[1], from[2]);
    TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(p);
    BRepExtrema_DistShapeShape dist(v, s);
    if (!dist.IsDone() || dist.NbSolution() < 1) return std::nullopt;

    gp_Pnt pb = dist.PointOnShape2(1);
    DistanceResult r;
    r.distance = dist.Value();
    r.point_a = from;
    r.point_b = {pb.X(), pb.Y(), pb.Z()};
    return r;
}

std::optional<std::array<double, 3>> face_midpoint(const Document& doc,
                                                   const EntityId& face) {
    TopoDS_Shape s = doc.resolve(face);
    if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return std::nullopt;
    const TopoDS_Face f = TopoDS::Face(s);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
    if (surf.IsNull()) return std::nullopt;
    Standard_Real umin = 0, umax = 0, vmin = 0, vmax = 0;
    BRepTools::UVBounds(f, umin, umax, vmin, vmax);
    const gp_Pnt p = surf->Value(0.5 * (umin + umax), 0.5 * (vmin + vmax));
    return std::array<double, 3>{p.X(), p.Y(), p.Z()};
}

std::optional<BBox> bounding_box(const Document& doc, const EntityId& id) {
    TopoDS_Shape s = doc.resolve(id);
    if (s.IsNull()) return std::nullopt;

    Bnd_Box box;
    BRepBndLib::AddOptimal(s, box, /*useTriangulation=*/Standard_False);
    if (box.IsVoid()) return std::nullopt;

    Standard_Real xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    BBox r;
    r.min = {xmin, ymin, zmin};
    r.max = {xmax, ymax, zmax};
    return r;
}

std::optional<MassProps> mass_properties(const Document& doc, const EntityId& body) {
    if (!doc.body(body)) return std::nullopt;
    TopoDS_Shape s = doc.resolve(body);
    if (s.IsNull()) return std::nullopt;

    GProp_GProps vol_props;
    BRepGProp::VolumeProperties(s, vol_props);
    GProp_GProps surf_props;
    BRepGProp::SurfaceProperties(s, surf_props);

    gp_Pnt c = vol_props.CentreOfMass();
    gp_Mat I = vol_props.MatrixOfInertia();

    MassProps r;
    r.volume = vol_props.Mass();
    r.surface_area = surf_props.Mass();
    r.center_of_mass = {c.X(), c.Y(), c.Z()};
    // gp_Mat is 1-based; store row-major.
    r.inertia = {I(1, 1), I(1, 2), I(1, 3), I(2, 1), I(2, 2), I(2, 3),
                 I(3, 1), I(3, 2), I(3, 3)};
    return r;
}

double edge_length(const Document& doc, const EntityId& edge) {
    TopoDS_Shape s = doc.resolve(edge);
    if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) return 0.0;
    GProp_GProps props;
    BRepGProp::LinearProperties(s, props);
    return props.Mass();
}

double face_area(const Document& doc, const EntityId& face) {
    TopoDS_Shape s = doc.resolve(face);
    if (s.IsNull() || s.ShapeType() != TopAbs_FACE) return 0.0;
    GProp_GProps props;
    BRepGProp::SurfaceProperties(s, props);
    return props.Mass();
}

static std::optional<gp_Dir> planar_outward_normal(const TopoDS_Shape& face) {
    if (face.IsNull() || face.ShapeType() != TopAbs_FACE) return std::nullopt;
    BRepAdaptor_Surface surf(TopoDS::Face(face));
    if (surf.GetType() != GeomAbs_Plane) return std::nullopt;
    gp_Dir n = surf.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
    return n;
}

std::optional<double> angle_between_faces(const Document& doc, const EntityId& f1,
                                          const EntityId& f2) {
    auto n1 = planar_outward_normal(doc.resolve(f1));
    auto n2 = planar_outward_normal(doc.resolve(f2));
    if (!n1 || !n2) return std::nullopt;
    return n1->Angle(*n2);
}

namespace {

double common_volume(const TopoDS_Shape& a, const TopoDS_Shape& b) {
    if (a.IsNull() || b.IsNull()) return 0.0;
    try {
        BRepAlgoAPI_Common common(a, b);
        if (!common.IsDone()) return 0.0;
        TopoDS_Shape c = common.Shape();
        if (c.IsNull()) return 0.0;
        GProp_GProps props;
        BRepGProp::VolumeProperties(c, props);
        double v = props.Mass();
        return v > 0.0 ? v : 0.0;
    } catch (...) {
        return 0.0;
    }
}

struct Entry {
    std::string kind;
    EntityId id;
    TopoDS_Shape shape;
};

}  // namespace

std::vector<InterferenceHit> check_interferences(const Document& doc, double volume_tol) {
    std::vector<Entry> entries;
    for (const auto& bid : doc.body_ids()) {
        const Body* b = doc.body(bid);
        if (!b || b->shape.IsNull()) continue;
        entries.push_back({"body", bid, b->shape});
    }
    for (const auto& inst : doc.instances()) {
        TopoDS_Shape s = resolved_shape(doc, inst);
        if (s.IsNull()) continue;
        entries.push_back({"instance", inst.id, s});
    }
    std::vector<InterferenceHit> hits;
    for (size_t i = 0; i < entries.size(); ++i) {
        for (size_t j = i + 1; j < entries.size(); ++j) {
            // Skip body vs its own instance (same solid counted twice).
            if (entries[i].kind == "body" && entries[j].kind == "instance") {
                const Instance* inst = doc.instance(entries[j].id);
                if (inst && inst->source_body == entries[i].id) continue;
            }
            if (entries[j].kind == "body" && entries[i].kind == "instance") {
                const Instance* inst = doc.instance(entries[i].id);
                if (inst && inst->source_body == entries[j].id) continue;
            }
            double v = common_volume(entries[i].shape, entries[j].shape);
            if (v > volume_tol) {
                hits.push_back({entries[i].kind, entries[i].id, entries[j].kind,
                                entries[j].id, v});
            }
        }
    }
    return hits;
}

}  // namespace sx::measure
