#include <catch.hpp>

#include "sx/document.hpp"
#include "sx/instances.hpp"
#include "sx/measure.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("overlapping instances report interference volume", "[interference]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(20, 20, 20), "Box");
    auto i1 = doc.add_instance(body, {0, 0, 0}, {0, 0, 0, 1}, "A");
    auto i2 = doc.add_instance(body, {10, 0, 0}, {0, 0, 0, 1}, "B");  // 10 mm overlap
    REQUIRE(!i1.is_null());
    REQUIRE(!i2.is_null());

    auto hits = measure::check_interferences(doc);
    REQUIRE_FALSE(hits.empty());
    double vol = 0.0;
    for (const auto& h : hits) vol += h.volume;
    // Overlap region 10x20x20 = 4000.
    CHECK(vol == Approx(4000.0).margin(1.0));
}

TEST_CASE("separated instances are interference-clean", "[interference]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    doc.add_instance(body, {0, 0, 0}, {0, 0, 0, 1}, "A");
    doc.add_instance(body, {50, 0, 0}, {0, 0, 0, 1}, "B");
    auto hits = measure::check_interferences(doc);
    CHECK(hits.empty());
}
