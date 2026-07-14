#include <catch.hpp>
#include <unordered_set>

#include "sx/ids.hpp"

TEST_CASE("EntityId generation is unique and round-trips", "[ids]") {
    std::unordered_set<sx::EntityId> seen;
    for (int i = 0; i < 1000; ++i) {
        auto id = sx::EntityId::generate();
        REQUIRE(!id.is_null());
        REQUIRE(seen.insert(id).second);

        auto s = id.str();
        REQUIRE(s.size() == 36);
        REQUIRE(s[14] == '4');  // version nibble
        REQUIRE(sx::EntityId::from_string(s) == id);
    }
}

TEST_CASE("EntityId parsing rejects garbage", "[ids]") {
    REQUIRE_THROWS(sx::EntityId::from_string("not-a-uuid"));
    REQUIRE_THROWS(sx::EntityId::from_string(""));
    REQUIRE_THROWS(sx::EntityId::from_string("12345678-1234-1234-1234-12345678901"));  // short
}

TEST_CASE("null EntityId", "[ids]") {
    sx::EntityId id;
    REQUIRE(id.is_null());
}
