#include <catch.hpp>

#include <cmath>

#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include "sx/commands_draft.hpp"
#include "sx/document.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

namespace {

EntityId find_side_face(Document& doc, const Body& b) {
    EntityId side;
    for (const auto& fid : b.subshape_ids.at(EntityKind::Face)) {
        auto desc = shape::describe_face(doc.resolve(fid));
        // Vertical side: not top (+Z) or bottom (-Z).
        if (desc.find("normal (0, 0, 1)") != std::string::npos) continue;
        if (desc.find("normal (0, 0, -1)") != std::string::npos) continue;
        if (desc.find("planar face") != std::string::npos) {
            side = fid;
            break;
        }
    }
    return side;
}

}  // namespace

TEST_CASE("draft tapers one side face of a box", "[draft]") {
    Document doc;
    CommandStack stack;
    auto body_id = doc.add_body(shape::make_box(20, 20, 30), "B");

    const Body* b0 = doc.body(body_id);
    const double vol0 = shape::volume(b0->shape);
    REQUIRE(vol0 == Approx(12000.0));
    const int faces0 = shape::count(b0->shape).faces;

    EntityId side = find_side_face(doc, *b0);
    REQUIRE(!side.is_null());

    const double angle = 5.0 * M_PI / 180.0;
    const gp_Dir pull(0, 0, 1);
    const gp_Pln neutral(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

    stack.push(doc, std::make_unique<DraftCommand>(
                        body_id, std::vector<EntityId>{side}, angle, pull, neutral));

    const Body* b = doc.body(body_id);
    REQUIRE(b != nullptr);
    REQUIRE(shape::is_valid(b->shape));
    const double vol1 = shape::volume(b->shape);
    REQUIRE(vol1 != Approx(vol0).epsilon(1e-9));
    REQUIRE(vol1 > 0.0);
    // Single planar-face draft on a box should not change topology.
    REQUIRE(shape::count(b->shape).faces == faces0);

    REQUIRE(stack.undo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol0).epsilon(1e-9));

    REQUIRE(stack.redo(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol1).epsilon(1e-9));
}

TEST_CASE("draft with bogus face id returns false and leaves body untouched", "[draft]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(20, 20, 30), "B");
    const double vol0 = shape::volume(doc.body(body_id)->shape);

    const double angle = 5.0 * M_PI / 180.0;
    const gp_Dir pull(0, 0, 1);
    const gp_Pln neutral(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    EntityId bogus = EntityId::generate();

    DraftCommand cmd(body_id, {bogus}, angle, pull, neutral);
    REQUIRE_FALSE(cmd.try_execute(doc));
    REQUIRE(shape::volume(doc.body(body_id)->shape) == Approx(vol0).epsilon(1e-9));
}
