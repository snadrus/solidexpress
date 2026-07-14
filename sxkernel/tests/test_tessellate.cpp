#include <catch.hpp>
#include <cmath>

#include "sx/document.hpp"
#include "sx/shape_utils.hpp"
#include "sx/tessellate.hpp"

using namespace sx;

TEST_CASE("tessellating a box yields 6 face meshes with sane data", "[tess]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");
    BodyMesh mesh = tessellate_body(doc, body_id);

    REQUIRE(mesh.body == body_id);
    REQUIRE(mesh.faces.size() == 6);
    REQUIRE(mesh.edges.size() == 12);

    const auto& face_ids = doc.body(body_id)->subshape_ids.at(EntityKind::Face);
    for (size_t i = 0; i < mesh.faces.size(); ++i) {
        const FaceMesh& fm = mesh.faces[i];
        REQUIRE(fm.face == face_ids[i]);
        REQUIRE(fm.positions.size() >= 4 * 3);  // at least a quad
        REQUIRE(fm.positions.size() == fm.normals.size());
        REQUIRE(fm.indices.size() % 3 == 0);
        REQUIRE(fm.indices.size() >= 6);  // at least two triangles

        // Indices in range; normals unit length.
        size_t vert_count = fm.positions.size() / 3;
        for (auto idx : fm.indices) REQUIRE(idx < vert_count);
        for (size_t v = 0; v < vert_count; ++v) {
            float len = std::sqrt(fm.normals[3 * v] * fm.normals[3 * v] +
                                  fm.normals[3 * v + 1] * fm.normals[3 * v + 1] +
                                  fm.normals[3 * v + 2] * fm.normals[3 * v + 2]);
            REQUIRE(len == Approx(1.0f).epsilon(0.01));
        }
        // All positions inside the box bounds (with tessellation slack).
        for (size_t v = 0; v < vert_count; ++v) {
            for (int a = 0; a < 3; ++a) {
                REQUIRE(fm.positions[3 * v + a] >= -0.01f);
                REQUIRE(fm.positions[3 * v + a] <= 10.01f);
            }
        }
    }
}

TEST_CASE("tessellated sphere approximates surface area", "[tess]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_sphere(5), "S");
    BodyMesh mesh = tessellate_body(doc, body_id, 0.05, 0.2);

    double tri_area = 0;
    for (const auto& fm : mesh.faces) {
        for (size_t t = 0; t + 2 < fm.indices.size(); t += 3) {
            auto px = [&](uint32_t i, int a) { return (double)fm.positions[3 * i + a]; };
            uint32_t i0 = fm.indices[t], i1 = fm.indices[t + 1], i2 = fm.indices[t + 2];
            double ux = px(i1, 0) - px(i0, 0), uy = px(i1, 1) - px(i0, 1), uz = px(i1, 2) - px(i0, 2);
            double vx = px(i2, 0) - px(i0, 0), vy = px(i2, 1) - px(i0, 1), vz = px(i2, 2) - px(i0, 2);
            double cx = uy * vz - uz * vy, cy = uz * vx - ux * vz, cz = ux * vy - uy * vx;
            tri_area += 0.5 * std::sqrt(cx * cx + cy * cy + cz * cz);
        }
    }
    double exact = 4.0 * 3.14159265358979 * 25.0;
    REQUIRE(tri_area == Approx(exact).epsilon(0.02));  // within 2%
}
