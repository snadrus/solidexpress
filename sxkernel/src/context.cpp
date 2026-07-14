#include "sx/context.hpp"

#include <sstream>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/entity.hpp"
#include "sx/features.hpp"
#include "sx/measure.hpp"

namespace sx {

std::string export_context_markdown(const Document& doc) {
    std::ostringstream out;
    out << "# Model context\n\n";
    out << "Entity ids are stable UUIDs; use them to reference bodies, faces, "
           "and features in commands.\n\n";

    out << "## Timeline\n\n";
    const auto& timeline = doc.graph().timeline();
    if (timeline.empty()) {
        out << "_empty_\n\n";
    } else {
        out << "```json\n" << doc.graph().to_json().dump(2) << "\n```\n\n";
    }

    out << "## Bodies\n\n";
    for (const auto& body_id : doc.body_ids()) {
        const Body* b = doc.body(body_id);
        out << "### " << b->name << " `" << body_id.str() << "`\n\n";
        if (auto mp = measure::mass_properties(doc, body_id)) {
            out << "- volume: " << mp->volume << " mm^3\n";
            out << "- surface area: " << mp->surface_area << " mm^2\n";
            out << "- center of mass: [" << mp->center_of_mass[0] << ", "
                << mp->center_of_mass[1] << ", " << mp->center_of_mass[2] << "]\n";
        }
        if (auto bb = measure::bounding_box(doc, body_id)) {
            out << "- bbox: [" << bb->min[0] << ", " << bb->min[1] << ", " << bb->min[2]
                << "] to [" << bb->max[0] << ", " << bb->max[1] << ", " << bb->max[2] << "]\n";
        }
        if (const Card* bc = doc.cards().find(body_id)) {
            if (!bc->aliases.empty()) out << "- aliases: " << bc->aliases << "\n";
            if (!bc->notes.empty()) out << "- notes: " << bc->notes << "\n";
        }
        out << "\n";

        // Face cards, including free text the user/AI attached.
        auto it = b->subshape_ids.find(EntityKind::Face);
        if (it != b->subshape_ids.end()) {
            for (const auto& face_id : it->second) {
                const Card* fc = doc.cards().find(face_id);
                if (!fc) continue;
                out << "- face `" << face_id.str() << "`: " << fc->digest;
                if (!fc->aliases.empty()) out << " — aka \"" << fc->aliases << "\"";
                if (!fc->notes.empty()) out << " — note: " << fc->notes;
                out << "\n";
            }
            out << "\n";
        }
    }
    return out.str();
}

}  // namespace sx
