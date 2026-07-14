#include "sx/sketch_tools.hpp"

#include <algorithm>
#include <cmath>

namespace sx::sketch_tools {
namespace {

constexpr double k_eps = 1e-6;
constexpr double k_pi = 3.14159265358979323846;

struct Vec2 {
    double x = 0, y = 0;
};

double dot(Vec2 a, Vec2 b) { return a.x * b.x + a.y * b.y; }
double cross(Vec2 a, Vec2 b) { return a.x * b.y - a.y * b.x; }
double hypot2(Vec2 v) { return std::hypot(v.x, v.y); }

Vec2 sub(Vec2 a, Vec2 b) { return {a.x - b.x, a.y - b.y}; }
Vec2 add(Vec2 a, Vec2 b) { return {a.x + b.x, a.y + b.y}; }
Vec2 mul(Vec2 a, double s) { return {a.x * s, a.y * s}; }

Vec2 unit(Vec2 v) {
    double len = hypot2(v);
    if (len < 1e-15) return {0, 0};
    return {v.x / len, v.y / len};
}

Vec2 line_end(const Sketch& s, const SketchEntity& e, PointRole role) {
    auto p = s.point_pos({e.id, role});
    return {(*p)[0], (*p)[1]};
}

void set_line_end(Sketch& s, const SketchEntity& e, PointRole role, Vec2 p) {
    if (role == PointRole::Start) {
        s.param_mut(e.params[0]) = p.x;
        s.param_mut(e.params[1]) = p.y;
    } else {
        s.param_mut(e.params[2]) = p.x;
        s.param_mut(e.params[3]) = p.y;
    }
}

}  // namespace

std::string fillet_corner(Sketch& s, const std::string& line_a_id,
                          const std::string& line_b_id, double radius) {
    if (radius <= 0) return "";

    EntityId id_a = EntityId::from_string(line_a_id);
    EntityId id_b = EntityId::from_string(line_b_id);
    const SketchEntity* ea = s.entity(id_a);
    const SketchEntity* eb = s.entity(id_b);
    if (!ea || !eb || ea->type != SketchEntityType::Line ||
        eb->type != SketchEntityType::Line)
        return "";

    Vec2 a0 = line_end(s, *ea, PointRole::Start);
    Vec2 a1 = line_end(s, *ea, PointRole::End);
    Vec2 b0 = line_end(s, *eb, PointRole::Start);
    Vec2 b1 = line_end(s, *eb, PointRole::End);

    // Find shared (or nearly shared) corner and which end of each line it is.
    PointRole role_a = PointRole::Self;
    PointRole role_b = PointRole::Self;
    Vec2 corner{};
    auto try_pair = [&](PointRole ra, Vec2 pa, PointRole rb, Vec2 pb) {
        if (hypot2(sub(pa, pb)) > k_eps) return false;
        role_a = ra;
        role_b = rb;
        corner = mul(add(pa, pb), 0.5);
        return true;
    };
    if (!try_pair(PointRole::Start, a0, PointRole::Start, b0) &&
        !try_pair(PointRole::Start, a0, PointRole::End, b1) &&
        !try_pair(PointRole::End, a1, PointRole::Start, b0) &&
        !try_pair(PointRole::End, a1, PointRole::End, b1))
        return "";

    Vec2 other_a = (role_a == PointRole::Start) ? a1 : a0;
    Vec2 other_b = (role_b == PointRole::Start) ? b1 : b0;
    // Unit directions from the corner along each remaining segment.
    Vec2 ua = unit(sub(other_a, corner));
    Vec2 ub = unit(sub(other_b, corner));
    double len_a = hypot2(sub(other_a, corner));
    double len_b = hypot2(sub(other_b, corner));
    if (hypot2(ua) < 0.5 || hypot2(ub) < 0.5) return "";

    double cos_a = std::clamp(dot(ua, ub), -1.0, 1.0);
    double alpha = std::acos(cos_a);
    // Parallel / anti-parallel / degenerate wedge — no unique fillet.
    if (alpha < k_eps || alpha > k_pi - k_eps) return "";

    // Trim distance along each arm: r / tan(α/2).
    double half = alpha * 0.5;
    double trim = radius / std::tan(half);
    if (trim > len_a + k_eps || trim > len_b + k_eps) return "";

    Vec2 trim_a = add(corner, mul(ua, trim));
    Vec2 trim_b = add(corner, mul(ub, trim));

    // Center lies along the angle bisector at distance r / sin(α/2).
    Vec2 bis = unit(add(ua, ub));
    if (hypot2(bis) < 0.5) return "";
    Vec2 center = add(corner, mul(bis, radius / std::sin(half)));

    double ang_a = std::atan2(trim_a.y - center.y, trim_a.x - center.x);
    double ang_b = std::atan2(trim_b.y - center.y, trim_b.x - center.x);
    // Fillet central angle is π − α (< π). Prefer the CCW sweep matching that.
    double expected = k_pi - alpha;
    double ccw = ang_b - ang_a;
    while (ccw < 0) ccw += 2.0 * k_pi;
    while (ccw >= 2.0 * k_pi) ccw -= 2.0 * k_pi;
    double start_ang = ang_a;
    double end_ang = ang_b;
    PointRole arc_start_role_line = role_a;
    PointRole arc_end_role_line = role_b;
    EntityId line_for_start = id_a;
    EntityId line_for_end = id_b;
    if (std::abs(ccw - expected) > std::abs((2.0 * k_pi - ccw) - expected)) {
        start_ang = ang_b;
        end_ang = ang_a;
        arc_start_role_line = role_b;
        arc_end_role_line = role_a;
        line_for_start = id_b;
        line_for_end = id_a;
    }
    // Normalize so end is CCW from start (possibly end < start in (-π, π] form).
    while (end_ang < start_ang) end_ang += 2.0 * k_pi;

    set_line_end(s, *ea, role_a, trim_a);
    set_line_end(s, *eb, role_b, trim_b);

    EntityId arc = s.add_arc(center.x, center.y, radius, start_ang, end_ang);

    s.add_constraint(ConstraintType::Coincident,
                     {{arc, PointRole::Start}, {line_for_start, arc_start_role_line}});
    s.add_constraint(ConstraintType::Coincident,
                     {{arc, PointRole::End}, {line_for_end, arc_end_role_line}});

    return arc.str();
}

std::vector<std::string> offset_entities(Sketch& s,
                                         const std::vector<std::string>& entity_ids,
                                         double distance) {
    std::vector<std::string> out;
    out.reserve(entity_ids.size());

    for (const std::string& sid : entity_ids) {
        EntityId id = EntityId::from_string(sid);
        const SketchEntity* e = s.entity(id);
        if (!e) continue;

        if (e->type == SketchEntityType::Line) {
            double x1 = s.param(e->params[0]);
            double y1 = s.param(e->params[1]);
            double x2 = s.param(e->params[2]);
            double y2 = s.param(e->params[3]);
            Vec2 dir = {x2 - x1, y2 - y1};
            double len = hypot2(dir);
            if (len < 1e-15) continue;
            // Left normal of the direction vector.
            Vec2 n = {-dir.y / len, dir.x / len};
            Vec2 o = mul(n, distance);
            EntityId nid =
                s.add_line(x1 + o.x, y1 + o.y, x2 + o.x, y2 + o.y);
            out.push_back(nid.str());
        } else if (e->type == SketchEntityType::Circle) {
            double cx = s.param(e->params[0]);
            double cy = s.param(e->params[1]);
            double r = s.param(e->params[2]);
            double nr = r + distance;
            if (nr <= 0) continue;
            EntityId nid = s.add_circle(cx, cy, nr);
            out.push_back(nid.str());
        }
        // Arcs and other kinds skipped in v1.
    }
    return out;
}

}  // namespace sx::sketch_tools
