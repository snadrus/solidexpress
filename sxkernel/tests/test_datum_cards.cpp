#include <catch.hpp>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/entity.hpp"

using namespace sx;

TEST_CASE("EntityKind string round-trips for datum kinds", "[datumcards]") {
    REQUIRE(std::string(to_string(EntityKind::DatumPlane)) == "datum_plane");
    REQUIRE(std::string(to_string(EntityKind::DatumAxis)) == "datum_axis");
    REQUIRE(std::string(to_string(EntityKind::DatumPoint)) == "datum_point");
    REQUIRE(entity_kind_from_string("datum_plane") == EntityKind::DatumPlane);
    REQUIRE(entity_kind_from_string("datum_axis") == EntityKind::DatumAxis);
    REQUIRE(entity_kind_from_string("datum_point") == EntityKind::DatumPoint);
}

TEST_CASE("add_datum creates semantic cards with kinds and titles", "[datumcards]") {
    Document doc;
    auto plane_id = doc.add_datum_plane({0, 0, 0}, {0, 0, 1});
    auto axis_id = doc.add_datum_axis({1, 2, 3}, {0, 1, 0});
    auto point_id = doc.add_datum_point({4, 5, 6});

    const Card* pc = doc.cards().find(plane_id);
    REQUIRE(pc != nullptr);
    REQUIRE(pc->kind == EntityKind::DatumPlane);
    REQUIRE(pc->title == "Datum Plane 1");
    REQUIRE(pc->digest.find("origin") != std::string::npos);
    REQUIRE(pc->digest.find("normal") != std::string::npos);

    const Card* ac = doc.cards().find(axis_id);
    REQUIRE(ac != nullptr);
    REQUIRE(ac->kind == EntityKind::DatumAxis);
    REQUIRE(ac->title == "Datum Axis 1");
    REQUIRE(ac->digest.find("direction") != std::string::npos);

    const Card* ptc = doc.cards().find(point_id);
    REQUIRE(ptc != nullptr);
    REQUIRE(ptc->kind == EntityKind::DatumPoint);
    REQUIRE(ptc->title == "Datum Point 1");
    REQUIRE(ptc->digest.find("position") != std::string::npos);

    // Second of each kind increments the title number.
    auto plane2 = doc.add_datum_plane({1, 0, 0}, {1, 0, 0});
    REQUIRE(doc.cards().find(plane2)->title == "Datum Plane 2");
}

TEST_CASE("datum card aliases survive ensure/upsert", "[datumcards]") {
    Document doc;
    auto plane_id = doc.add_datum_plane({0, 0, 0}, {0, 0, 1});
    doc.cards().set_alias(plane_id, "mid plane");
    doc.cards().set_notes(plane_id, "keep for mating");

    doc.ensure_datum_cards();

    const Card* after = doc.cards().find(plane_id);
    REQUIRE(after != nullptr);
    REQUIRE(after->kind == EntityKind::DatumPlane);
    REQUIRE(after->aliases == "mid plane");
    REQUIRE(after->notes == "keep for mating");
    REQUIRE(after->digest.find("origin") != std::string::npos);
}

TEST_CASE("remove_datum erases the card", "[datumcards]") {
    Document doc;
    auto axis_id = doc.add_datum_axis({0, 0, 0}, {0, 0, 1});
    REQUIRE(doc.cards().find(axis_id) != nullptr);
    REQUIRE(doc.remove_datum(axis_id));
    REQUIRE(doc.cards().find(axis_id) == nullptr);
}

TEST_CASE("restore_datum upserts a card", "[datumcards]") {
    Document doc;
    DatumPlane p;
    p.id = EntityId::generate();
    p.name = "XY";
    p.origin = {0, 0, 0};
    p.normal = {0, 0, 1};
    p.x_dir = {1, 0, 0};
    const EntityId id = p.id;
    doc.restore_datum(Datum{std::move(p)});

    const Card* c = doc.cards().find(id);
    REQUIRE(c != nullptr);
    REQUIRE(c->kind == EntityKind::DatumPlane);
    REQUIRE(c->title == "XY");
}
