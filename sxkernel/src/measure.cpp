#include "sx/measure.hpp"

#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <gp_Dir.hxx>
#include <gp_Mat.hxx>
#include <gp_Pnt.hxx>

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

}  // namespace sx::measure
