#include "sx/commands_graph.hpp"

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/log.hpp"

namespace sx {

void GraphSnapshotCommand::restore(Document& doc, const nlohmann::json& snapshot) {
    // Remove bodies owned by the current graph before swapping it out; the
    // incoming graph has no memory of bodies it did not create.
    for (const auto& f : doc.graph().timeline()) {
        if (!f.output_body.is_null() && doc.body(f.output_body)) doc.remove_body(f.output_body);
    }
    doc.set_graph(FeatureGraph::from_json(snapshot));
    std::string err;
    if (!doc.graph().regenerate(doc, &err))
        log::error("GraphSnapshotCommand: regenerate failed: " + err);
}

void GraphSnapshotCommand::execute(Document& doc) { restore(doc, after_); }
void GraphSnapshotCommand::undo(Document& doc) { restore(doc, before_); }

}  // namespace sx
