#include <catch.hpp>

#include "sx/cards.hpp"
#include "sx/context.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("context export covers timeline, bodies, and free text", "[context]") {
    Document doc;
    Feature box;
    box.type = FeatureType::Primitive;
    box.name = "Base";
    box.params = {{"kind", "box"}, {"a", 20.0}, {"b", 20.0}, {"c", 10.0}};
    auto fid = doc.graph().add(std::move(box));
    std::string err;
    REQUIRE(doc.graph().regenerate(doc, &err));
    EntityId body_id = doc.graph().feature(fid)->output_body;

    auto face_id = doc.subshape_id(body_id, EntityKind::Face, 1);
    doc.cards().set_alias(face_id, "the mounting face");
    doc.cards().set_notes(body_id, "keep walls above 2mm");

    std::string md = export_context_markdown(doc);
    REQUIRE(md.find("# Model context") != std::string::npos);
    REQUIRE(md.find(fid.str()) != std::string::npos);          // timeline JSON
    REQUIRE(md.find(body_id.str()) != std::string::npos);      // body section
    REQUIRE(md.find(face_id.str()) != std::string::npos);      // face card line
    REQUIRE(md.find("the mounting face") != std::string::npos);
    REQUIRE(md.find("keep walls above 2mm") != std::string::npos);
    REQUIRE(md.find("volume: 4000") != std::string::npos);
    REQUIRE(md.find("\"kind\": \"box\"") != std::string::npos);
}

TEST_CASE("context export of empty document", "[context]") {
    Document doc;
    std::string md = export_context_markdown(doc);
    REQUIRE(md.find("_empty_") != std::string::npos);
}
