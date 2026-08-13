#include <catch.hpp>
#include <cstdio>

#include "sx/document.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sxp.hpp"

using namespace sx;

TEST_CASE("auto_explode offsets instances along +Z", "[explode]") {
    Document doc;
    auto body = doc.add_body(shape::make_box(10, 10, 10), "Box");
    auto i1 = doc.add_instance(body, {0, 0, 0}, {0, 0, 0, 1}, "A");
    auto i2 = doc.add_instance(body, {30, 0, 0}, {0, 0, 0, 1}, "B");
    REQUIRE(doc.auto_explode(25.0));
    CHECK(doc.explode().active);
    REQUIRE(doc.explode().offsets.count(i1) == 1);
    REQUIRE(doc.explode().offsets.count(i2) == 1);
    CHECK(doc.explode().offsets.at(i1)[2] == Approx(25.0));
    CHECK(doc.explode().offsets.at(i2)[2] == Approx(50.0));
    REQUIRE(doc.set_explode_active(false));
    CHECK_FALSE(doc.explode().active);
    // Offsets retained for re-activate.
    REQUIRE(doc.set_explode_active(true));
    CHECK(doc.explode().active);
    CHECK(doc.explode().offsets.at(i2)[2] == Approx(50.0));
}

TEST_CASE("explode persists through .sxp", "[explode]") {
    const char* path = "/tmp/sx_explode_roundtrip.sxp";
    {
        Document doc;
        auto body = doc.add_body(shape::make_box(5, 5, 5), "Box");
        doc.add_instance(body, {0, 0, 0}, {0, 0, 0, 1}, "A");
        doc.add_instance(body, {20, 0, 0}, {0, 0, 0, 1}, "B");
        REQUIRE(doc.auto_explode(15.0));
        REQUIRE(save_sxp(doc, path));
    }
    Document loaded;
    REQUIRE(load_sxp(loaded, path));
    CHECK(loaded.explode().active);
    CHECK(loaded.explode().spacing == Approx(15.0));
    CHECK(loaded.explode().offsets.size() == 2);
    std::remove(path);
}
