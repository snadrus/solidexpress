#include "sx/context.hpp"

#include <sstream>

#include "sx/cards.hpp"
#include "sx/document.hpp"
#include "sx/entity.hpp"
#include "sx/features.hpp"
#include "sx/measure.hpp"

namespace sx {

namespace {
void write_vec3(std::ostringstream& out, const std::array<double, 3>& v) {
    out << "[" << v[0] << ", " << v[1] << ", " << v[2] << "]";
}
}  // namespace

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

    // Variables drive "=expr" feature params; include them so an AI can
    // reason about (and suggest edits to) the parametric intent.
    const auto& vars = doc.graph().variables().entries();
    if (!vars.empty()) {
        out << "## Variables\n\n";
        std::map<std::string, double> env;
        bool env_ok = true;
        try {
            env = doc.graph().variables().evaluate();
        } catch (const std::exception&) {
            env_ok = false;
        }
        for (const auto& [name, expr] : vars) {
            out << "- `" << name << "` = `" << expr << "`";
            if (env_ok) out << " → " << env[name];
            out << "\n";
        }
        if (!env_ok) out << "\n_warning: variable table currently fails to evaluate_\n";
        out << "\n";
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

    if (!doc.datums().empty()) {
        out << "## Datums\n\n";
        for (const auto& d : doc.datums()) {
            if (const auto* p = std::get_if<DatumPlane>(&d)) {
                out << "- plane `" << p->id.str() << "` \"" << p->name << "\": origin ";
                write_vec3(out, p->origin);
                out << ", normal ";
                write_vec3(out, p->normal);
            } else if (const auto* a = std::get_if<DatumAxis>(&d)) {
                out << "- axis `" << a->id.str() << "` \"" << a->name << "\": point ";
                write_vec3(out, a->point);
                out << ", direction ";
                write_vec3(out, a->direction);
            } else if (const auto* pt = std::get_if<DatumPoint>(&d)) {
                out << "- point `" << pt->id.str() << "` \"" << pt->name << "\": ";
                write_vec3(out, pt->position);
            }
            // Free text attached to the datum card, if any.
            const EntityId did = std::visit([](const auto& v) { return v.id; }, d);
            if (const Card* dc = doc.cards().find(did)) {
                if (!dc->aliases.empty()) out << " — aka \"" << dc->aliases << "\"";
                if (!dc->notes.empty()) out << " — note: " << dc->notes;
            }
            out << "\n";
        }
        out << "\n";
    }

    if (!doc.instances().empty()) {
        out << "## Instances\n\n";
        for (const auto& inst : doc.instances()) {
            out << "- `" << inst.id.str() << "` \"" << inst.name << "\": instance of `"
                << inst.source_body.str() << "` at ";
            write_vec3(out, inst.translation);
            const auto& q = inst.rotation_quat;
            if (q[0] != 0 || q[1] != 0 || q[2] != 0) {
                out << ", quat [" << q[0] << ", " << q[1] << ", " << q[2] << ", " << q[3]
                    << "]";
            }
            out << "\n";
        }
        out << "\n";
    }
    return out.str();
}

}  // namespace sx
