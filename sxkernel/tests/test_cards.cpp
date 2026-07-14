#include <catch.hpp>

#include "sx/cards.hpp"

using namespace sx;

static Card sample_card() {
    Card c;
    c.id = EntityId::generate();
    c.kind = EntityKind::Face;
    c.title = "Face 3 of Box 1";
    c.digest = "planar face, area 100 mm^2, normal (0, 0, 1)";
    c.relations = {EntityId::generate()};
    return c;
}

TEST_CASE("card markdown round trip", "[cards]") {
    Card c = sample_card();
    c.aliases = "the top face\nla cara superior";
    c.notes = "This face mates with the lid.";

    std::string md = c.to_markdown();
    REQUIRE(md.find("# Face 3 of Box 1") == 0);
    REQUIRE(md.find("- uuid: " + c.id.str()) != std::string::npos);
    REQUIRE(md.find("## Digest") != std::string::npos);

    auto parsed = Card::from_markdown(md);
    REQUIRE(parsed.has_value());
    REQUIRE(parsed->id == c.id);
    REQUIRE(parsed->kind == EntityKind::Face);
    REQUIRE(parsed->title == c.title);
    REQUIRE(parsed->digest == c.digest);
    REQUIRE(parsed->aliases == c.aliases);
    REQUIRE(parsed->notes == c.notes);
    REQUIRE(parsed->relations.size() == 1);
    REQUIRE(parsed->relations[0] == c.relations[0]);
}

TEST_CASE("registry preserves free text across machine regeneration", "[cards]") {
    CardRegistry reg;
    Card c = sample_card();
    EntityId id = c.id;
    reg.upsert(c);

    reg.set_alias(id, "the mounting face");
    reg.set_notes(id, "keep flat within 0.05");

    // Simulate a rebuild: machine sections regenerate, free text must survive.
    Card regen = c;
    regen.digest = "planar face, area 150 mm^2, normal (0, 0, 1)";  // geometry changed
    regen.aliases.clear();
    regen.notes.clear();
    reg.upsert(regen);

    const Card* after = reg.find(id);
    REQUIRE(after != nullptr);
    REQUIRE(after->digest.find("150") != std::string::npos);
    REQUIRE(after->aliases == "the mounting face");
    REQUIRE(after->notes == "keep flat within 0.05");
}

TEST_CASE("from_markdown rejects malformed input", "[cards]") {
    REQUIRE(!Card::from_markdown("").has_value());
    REQUIRE(!Card::from_markdown("# hi\nno uuid here").has_value());
}
