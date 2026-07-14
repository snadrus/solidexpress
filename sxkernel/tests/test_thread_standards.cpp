#include <catch.hpp>

#include <cmath>
#include <set>
#include <string>

#include "sx/thread_standards.hpp"

using namespace sx;

TEST_CASE("threadstd: M8 coarse lookup", "[threadstd]") {
    auto t = find_thread("M8");
    REQUIRE(t.has_value());
    REQUIRE(t->designation == "M8");
    REQUIRE(t->major_diameter_mm == Approx(8.0).epsilon(1e-12));
    REQUIRE(t->pitch_mm == Approx(1.25).epsilon(1e-12));
    REQUIRE_FALSE(t->internal);
}

TEST_CASE("threadstd: M8x1.0 fine lookup", "[threadstd]") {
    auto t = find_thread("M8x1.0");
    REQUIRE(t.has_value());
    REQUIRE(t->designation == "M8x1.0");
    REQUIRE(t->major_diameter_mm == Approx(8.0).epsilon(1e-12));
    REQUIRE(t->pitch_mm == Approx(1.0).epsilon(1e-12));

    auto t2 = find_thread("M8x1");
    REQUIRE(t2.has_value());
    REQUIRE(t2->pitch_mm == Approx(1.0).epsilon(1e-12));
}

TEST_CASE("threadstd: case-insensitive and trim", "[threadstd]") {
    auto a = find_thread("m8");
    auto b = find_thread("M8X1.25");
    auto c = find_thread("  M8  ");
    REQUIRE(a.has_value());
    REQUIRE(b.has_value());
    REQUIRE(c.has_value());
    REQUIRE(a->pitch_mm == Approx(1.25).epsilon(1e-12));
    REQUIRE(b->pitch_mm == Approx(1.25).epsilon(1e-12));
    REQUIRE(c->designation == "M8");
}

TEST_CASE("threadstd: unknown returns nullopt", "[threadstd]") {
    REQUIRE_FALSE(find_thread("M999").has_value());
    REQUIRE_FALSE(find_thread("bogus").has_value());
    REQUIRE_FALSE(find_thread("").has_value());
    REQUIRE_FALSE(find_thread("M8x9.99").has_value());
}

TEST_CASE("threadstd: minor diameter and thread depth (M8)", "[threadstd]") {
    auto t = find_thread("M8");
    REQUIRE(t.has_value());
    // ISO 60°: minor = major - 2 * 0.6134 * pitch ≈ 6.4665
    REQUIRE(t->minor_diameter_mm() == Approx(8.0 - 2.0 * 0.6134 * 1.25).epsilon(1e-12));
    REQUIRE(t->minor_diameter_mm() == Approx(6.4665).margin(1e-4));
    REQUIRE(t->thread_depth_mm() == Approx(0.6134 * 1.25).epsilon(1e-12));
}

TEST_CASE("threadstd: imperial 1/4-20 UNC", "[threadstd]") {
    auto t = find_thread("1/4-20");
    REQUIRE(t.has_value());
    REQUIRE(t->designation == "1/4-20 UNC");
    REQUIRE(t->major_diameter_mm == Approx(6.35).epsilon(1e-9));
    REQUIRE(t->pitch_mm == Approx(25.4 / 20.0).epsilon(1e-12));
    REQUIRE(t->pitch_mm == Approx(1.27).epsilon(1e-12));

    auto named = find_thread("1/4-20 UNC");
    REQUIRE(named.has_value());
    REQUIRE(named->designation == "1/4-20 UNC");
}

TEST_CASE("threadstd: #10-32 UNF lookup", "[threadstd]") {
    auto t = find_thread("#10-32");
    REQUIRE(t.has_value());
    REQUIRE(t->designation == "#10-32 UNF");
    REQUIRE(t->major_diameter_mm == Approx(0.190 * 25.4).epsilon(1e-9));
    REQUIRE(t->pitch_mm == Approx(25.4 / 32.0).epsilon(1e-12));

    auto named = find_thread("#10-32 UNF");
    REQUIRE(named.has_value());
    REQUIRE(named->designation == "#10-32 UNF");
}

TEST_CASE("threadstd: table non-empty and unique designations", "[threadstd]") {
    const auto& table = thread_table();
    REQUIRE_FALSE(table.empty());
    REQUIRE(table.size() >= 30);

    std::set<std::string> seen;
    for (const auto& e : table) {
        REQUIRE_FALSE(e.designation.empty());
        REQUIRE(seen.insert(e.designation).second);
        REQUIRE(e.major_diameter_mm > 0.0);
        REQUIRE(e.pitch_mm > 0.0);
        REQUIRE_FALSE(e.internal);
    }
}
