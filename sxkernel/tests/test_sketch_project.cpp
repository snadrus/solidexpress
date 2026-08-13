#include <catch.hpp>

#include <gp_Dir.hxx>

#include "sx/document.hpp"
#include "sx/mates.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"
#include "sx/sketch_project.hpp"

using namespace sx;

TEST_CASE("convert_face_edges projects box top into four lines", "[sketchproject]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(40, 30, 10), "Box");
    EntityId top;
    for (const auto& fid : doc.body(body)->subshape_ids.at(EntityKind::Face)) {
        auto pl = mate_plane(doc, {}, fid);
        if (pl && pl->normal.IsEqual(gp_Dir(0, 0, 1), 1e-6)) {
            top = fid;
            break;
        }
    }
    REQUIRE(!top.is_null());

    SketchPlane pl;
    pl.origin = {20, 15, 10};
    pl.x_dir = {1, 0, 0};
    pl.y_dir = {0, 1, 0};
    Sketch sk("OnTop", pl);
    auto ids = convert_face_edges(sk, doc, top);
    REQUIRE(ids.size() == 4);
    int lines = 0;
    for (const auto& e : sk.entities()) {
        if (e.type == SketchEntityType::Line) ++lines;
    }
    REQUIRE(lines == 4);
}
