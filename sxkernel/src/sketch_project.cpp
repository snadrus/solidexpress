#include "sx/sketch_project.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepTools.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <cmath>

#include "sx/document.hpp"

namespace sx {

namespace {

struct Frame {
    gp_Pnt origin;
    gp_Dir x;
    gp_Dir y;
    gp_Dir n;
};

Frame frame_of(const Sketch& sk) {
    const auto& pl = sk.plane();
    return Frame{
        gp_Pnt(pl.origin[0], pl.origin[1], pl.origin[2]),
        gp_Dir(pl.x_dir[0], pl.x_dir[1], pl.x_dir[2]),
        gp_Dir(pl.y_dir[0], pl.y_dir[1], pl.y_dir[2]),
        gp_Dir(pl.normal()[0], pl.normal()[1], pl.normal()[2]),
    };
}

std::array<double, 2> to_uv(const Frame& f, const gp_Pnt& p) {
    gp_Vec v(f.origin, p);
    return {v.Dot(gp_Vec(f.x)), v.Dot(gp_Vec(f.y))};
}

bool nearly_on_plane(const Frame& f, const gp_Pnt& p, double tol = 1e-4) {
    return std::abs(gp_Vec(f.origin, p).Dot(gp_Vec(f.n))) < tol;
}

}  // namespace

std::vector<std::string> convert_face_edges(Sketch& sketch, const Document& doc,
                                            const EntityId& face_id) {
    std::vector<std::string> out;
    TopoDS_Shape sh = doc.resolve(face_id);
    if (sh.IsNull() || sh.ShapeType() != TopAbs_FACE) return out;
    TopoDS_Face face = TopoDS::Face(sh);
    TopoDS_Wire wire = BRepTools::OuterWire(face);
    if (wire.IsNull()) return out;

    Frame fr = frame_of(sketch);
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(wire, TopAbs_EDGE, edges);
    for (int i = 1; i <= edges.Extent(); ++i) {
        TopoDS_Edge e = TopoDS::Edge(edges(i));
        if (e.IsNull()) continue;
        BRepAdaptor_Curve curve(e);
        const GeomAbs_CurveType ctype = curve.GetType();
        if (ctype == GeomAbs_Line) {
            gp_Pnt p0 = curve.Value(curve.FirstParameter());
            gp_Pnt p1 = curve.Value(curve.LastParameter());
            if (!nearly_on_plane(fr, p0) || !nearly_on_plane(fr, p1)) {
                // Orthographic drop onto the sketch plane.
                auto drop = [&](gp_Pnt p) {
                    double h = gp_Vec(fr.origin, p).Dot(gp_Vec(fr.n));
                    return p.Translated(gp_Vec(fr.n) * (-h));
                };
                p0 = drop(p0);
                p1 = drop(p1);
            }
            auto u0 = to_uv(fr, p0);
            auto u1 = to_uv(fr, p1);
            if (std::hypot(u1[0] - u0[0], u1[1] - u0[1]) < 1e-6) continue;
            out.push_back(sketch.add_line(u0[0], u0[1], u1[0], u1[1]).str());
        } else if (ctype == GeomAbs_Circle) {
            gp_Circ c = curve.Circle();
            gp_Pnt ctr = c.Location();
            if (!nearly_on_plane(fr, ctr)) {
                double h = gp_Vec(fr.origin, ctr).Dot(gp_Vec(fr.n));
                ctr = ctr.Translated(gp_Vec(fr.n) * (-h));
            }
            // Only full circles whose axis aligns with the sketch normal.
            if (std::abs(std::abs(c.Axis().Direction().Dot(fr.n)) - 1.0) > 1e-3)
                continue;
            auto uc = to_uv(fr, ctr);
            double r = c.Radius();
            if (r < 1e-6) continue;
            double t0 = curve.FirstParameter();
            double t1 = curve.LastParameter();
            if (std::abs((t1 - t0) - 2.0 * M_PI) < 1e-3 ||
                std::abs(std::abs(t1 - t0) - 2.0 * M_PI) < 1e-3) {
                out.push_back(sketch.add_circle(uc[0], uc[1], r).str());
            } else {
                out.push_back(sketch.add_arc(uc[0], uc[1], r, t0, t1).str());
            }
        }
        // Other curve types skipped in v1.
    }
    return out;
}

}  // namespace sx
