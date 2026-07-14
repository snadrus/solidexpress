#include "sx/drawings.hpp"

#include <BRepAdaptor_Curve.hxx>
#include <BRepLib.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>

#include <algorithm>
#include <fstream>
#include <limits>
#include <sstream>

#include "sx/document.hpp"

namespace sx::drawings {

namespace {

constexpr double kDeflection = 0.05;  // mm chord tolerance for edge sampling

void collect_polylines(const TopoDS_Shape& compound, std::vector<Polyline2>& out) {
    if (compound.IsNull()) return;
    // HLR outline edges only carry 2D curves; build 3D curves before sampling.
    BRepLib::BuildCurves3d(compound);
    for (TopExp_Explorer ex(compound, TopAbs_EDGE); ex.More(); ex.Next()) {
        const TopoDS_Edge& edge = TopoDS::Edge(ex.Current());
        // Outline edges that still lack a 3D curve after BuildCurves3d would
        // crash the adaptor; skip them.
        double cf, cl;
        if (BRep_Tool::Curve(edge, cf, cl).IsNull()) continue;
        BRepAdaptor_Curve curve(edge);
        GCPnts_QuasiUniformDeflection sampler(curve, kDeflection);
        if (!sampler.IsDone() || sampler.NbPoints() < 2) continue;
        Polyline2 line;
        line.reserve(static_cast<size_t>(sampler.NbPoints()));
        for (int i = 1; i <= sampler.NbPoints(); ++i) {
            gp_Pnt p = sampler.Value(i);
            // HLR output lies in the projection plane: z ~ 0 in view coords.
            line.push_back({p.X(), p.Y()});
        }
        out.push_back(std::move(line));
    }
}

void grow_bounds(ViewProjection& v) {
    bool first = true;
    for (const auto* set : {&v.visible, &v.hidden}) {
        for (const auto& line : *set) {
            for (const auto& p : line) {
                if (first) {
                    v.min_x = v.max_x = p[0];
                    v.min_y = v.max_y = p[1];
                    first = false;
                } else {
                    v.min_x = std::min(v.min_x, p[0]);
                    v.max_x = std::max(v.max_x, p[0]);
                    v.min_y = std::min(v.min_y, p[1]);
                    v.max_y = std::max(v.max_y, p[1]);
                }
            }
        }
    }
}

}  // namespace

ViewProjection project(const TopoDS_Shape& shape, const gp_Dir& view_dir, const gp_Dir& up) {
    ViewProjection out;
    if (shape.IsNull()) return out;

    // Projector frame: N points from the model toward the viewer; sheet X
    // completes a right-handed frame so that sheet Y is `up`.
    gp_Dir toward_viewer = view_dir.Reversed();
    gp_Dir sheet_x = up.Crossed(toward_viewer);
    gp_Ax2 frame(gp_Pnt(0, 0, 0), toward_viewer, sheet_x);

    Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
    algo->Add(shape);
    algo->Projector(HLRAlgo_Projector(frame));
    algo->Update();
    algo->Hide();

    HLRBRep_HLRToShape extractor(algo);
    collect_polylines(extractor.VCompound(), out.visible);
    collect_polylines(extractor.OutLineVCompound(), out.visible);
    collect_polylines(extractor.HCompound(), out.hidden);
    collect_polylines(extractor.OutLineHCompound(), out.hidden);
    grow_bounds(out);
    return out;
}

namespace {

void write_polylines(std::ostringstream& svg, const std::vector<Polyline2>& lines,
                     double ox, double oy, double min_x, double min_y, double scale,
                     double sheet_h, const char* style) {
    for (const auto& line : lines) {
        svg << "  <polyline fill=\"none\" " << style << " points=\"";
        for (size_t i = 0; i < line.size(); ++i) {
            double x = (ox + (line[i][0] - min_x)) * scale;
            double y = sheet_h - (oy + (line[i][1] - min_y)) * scale;  // flip y
            if (i) svg << ' ';
            svg << x << ',' << y;
        }
        svg << "\"/>\n";
    }
}

}  // namespace

bool write_svg(const std::vector<PlacedView>& views, const std::string& path,
               double scale, double margin) {
    double sheet_w = 0, sheet_h = 0;
    for (const auto& pv : views) {
        sheet_w = std::max(sheet_w, pv.offset_x + (pv.view.max_x - pv.view.min_x));
        sheet_h = std::max(sheet_h, pv.offset_y + (pv.view.max_y - pv.view.min_y));
    }
    sheet_w = (sheet_w + 2 * margin) * scale;
    sheet_h = (sheet_h + 2 * margin) * scale;

    std::ostringstream svg;
    svg << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" << sheet_w << "mm\" height=\""
        << sheet_h << "mm\" viewBox=\"0 0 " << sheet_w << ' ' << sheet_h << "\">\n";
    for (const auto& pv : views) {
        const double ox = margin + pv.offset_x;
        const double oy = margin + pv.offset_y;
        write_polylines(svg, pv.view.visible, ox, oy, pv.view.min_x, pv.view.min_y, scale,
                        sheet_h, "stroke=\"black\" stroke-width=\"0.35\"");
        write_polylines(svg, pv.view.hidden, ox, oy, pv.view.min_x, pv.view.min_y, scale,
                        sheet_h,
                        "stroke=\"gray\" stroke-width=\"0.18\" stroke-dasharray=\"2,1\"");
        if (!pv.label.empty()) {
            svg << "  <text x=\"" << (margin + pv.offset_x) * scale << "\" y=\""
                << sheet_h - (oy - 4.0) * scale
                << "\" font-size=\"4\" font-family=\"sans-serif\">" << pv.label
                << "</text>\n";
        }
    }
    svg << "</svg>\n";

    std::ofstream f(path);
    if (!f) return false;
    f << svg.str();
    return static_cast<bool>(f);
}

bool export_three_view_svg(const Document& doc, const std::string& path, double scale) {
    TopoDS_Compound all;
    BRep_Builder builder;
    builder.MakeCompound(all);
    bool any = false;
    for (const auto& id : doc.body_ids()) {
        const Body* b = doc.body(id);
        if (b && !b->shape.IsNull()) {
            builder.Add(all, b->shape);
            any = true;
        }
    }
    if (!any) return false;

    // Kernel frame is Z-up. Third-angle-ish layout: front bottom-left, top
    // above it, right view to the right.
    ViewProjection front = project(all, gp_Dir(0, 1, 0), gp_Dir(0, 0, 1));
    ViewProjection top = project(all, gp_Dir(0, 0, -1), gp_Dir(0, 1, 0));
    ViewProjection right = project(all, gp_Dir(-1, 0, 0), gp_Dir(0, 0, 1));

    const double gap = 15.0;
    const double front_w = front.max_x - front.min_x;
    const double front_h = front.max_y - front.min_y;
    std::vector<PlacedView> views;
    views.push_back({std::move(front), "FRONT", 0, 0});
    views.push_back({std::move(top), "TOP", 0, front_h + gap});
    views.push_back({std::move(right), "RIGHT", front_w + gap, 0});
    return write_svg(views, path, scale);
}

}  // namespace sx::drawings
