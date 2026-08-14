#include "sx/dxf.hpp"

#include <cctype>
#include <cmath>
#include <fstream>
#include <sstream>

#include "sx/document.hpp"
#include "sx/features.hpp"

namespace sx {
namespace {

std::string trim(std::string s) {
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(s.begin());
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    return s;
}

bool next_pair(std::istream& in, int& code, std::string& value) {
    std::string line;
    if (!std::getline(in, line)) return false;
    try {
        code = std::stoi(trim(line));
    } catch (...) {
        return false;
    }
    if (!std::getline(in, value)) return false;
    value = trim(value);
    return true;
}

}  // namespace

std::vector<DxfEntity> read_dxf(const std::string& path, std::string* err) {
    std::ifstream in(path);
    if (!in) {
        if (err) *err = "cannot open DXF " + path;
        return {};
    }
    std::vector<DxfEntity> out;
    bool in_entities = false;
    int code = 0;
    std::string value;
    DxfEntity cur;
    bool have = false;
    auto flush = [&] {
        if (!have) return;
        if (cur.kind == DxfEntity::Kind::Line || cur.radius > 0.0) out.push_back(cur);
        have = false;
        cur = {};
    };
    while (next_pair(in, code, value)) {
        if (code == 0 && value == "SECTION") {
            int c2 = 0;
            std::string v2;
            if (next_pair(in, c2, v2) && c2 == 2 && v2 == "ENTITIES") in_entities = true;
            continue;
        }
        if (code == 0 && value == "ENDSEC") {
            if (in_entities) flush();
            in_entities = false;
            continue;
        }
        if (!in_entities) continue;
        if (code == 0) {
            flush();
            if (value == "LINE") {
                cur.kind = DxfEntity::Kind::Line;
                have = true;
            } else if (value == "CIRCLE") {
                cur.kind = DxfEntity::Kind::Circle;
                have = true;
            } else if (value == "ARC") {
                cur.kind = DxfEntity::Kind::Arc;
                have = true;
            } else if (value == "LWPOLYLINE" || value == "POLYLINE") {
                // Treat as a sequence of LINE vertices collected below.
                cur.kind = DxfEntity::Kind::Line;
                have = false;
            }
            continue;
        }
        if (!have) continue;
        switch (code) {
            case 10: cur.x1 = std::stod(value); cur.cx = cur.x1; break;
            case 20: cur.y1 = std::stod(value); cur.cy = cur.y1; break;
            case 11: cur.x2 = std::stod(value); break;
            case 21: cur.y2 = std::stod(value); break;
            case 40: cur.radius = std::stod(value); break;
            case 50: cur.start_angle = std::stod(value); break;
            case 51: cur.end_angle = std::stod(value); break;
            default: break;
        }
    }
    flush();
    if (out.empty() && err) *err = "no LINE/CIRCLE/ARC entities in " + path;
    return out;
}

int add_dxf_to_sketch(Sketch& sketch, const std::vector<DxfEntity>& entities) {
    int n = 0;
    for (const auto& e : entities) {
        if (e.kind == DxfEntity::Kind::Line) {
            sketch.add_line(e.x1, e.y1, e.x2, e.y2);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Circle) {
            sketch.add_circle(e.cx, e.cy, e.radius);
            ++n;
        } else if (e.kind == DxfEntity::Kind::Arc) {
            const double s = e.start_angle * M_PI / 180.0;
            const double t = e.end_angle * M_PI / 180.0;
            sketch.add_arc(e.cx, e.cy, e.radius, s, t);
            ++n;
        }
    }
    return n;
}

EntityId import_dxf_sketch(Document& doc, const std::string& path, std::string* err) {
    auto ents = read_dxf(path, err);
    if (ents.empty()) return {};
    auto sk = std::make_shared<Sketch>("DXF");
    if (add_dxf_to_sketch(*sk, ents) == 0) {
        if (err) *err = "DXF produced no sketch entities";
        return {};
    }
    Feature f;
    f.type = FeatureType::Sketch;
    f.name = "DXF";
    f.sketch = std::move(sk);
    return doc.graph().add(std::move(f));
}

}  // namespace sx
