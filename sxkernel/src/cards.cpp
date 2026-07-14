#include "sx/cards.hpp"

#include <sstream>

namespace sx {

std::string Card::to_markdown() const {
    std::ostringstream md;
    md << "# " << title << "\n\n";
    md << "- uuid: " << id.str() << "\n";
    md << "- kind: " << to_string(kind) << "\n\n";
    md << "## Digest\n\n" << digest << "\n\n";
    md << "## Relations\n\n";
    for (const auto& r : relations) md << "- " << r.str() << "\n";
    if (relations.empty()) md << "(none)\n";
    md << "\n## Aliases\n\n" << aliases << "\n\n";
    md << "## Notes\n\n" << notes << "\n";
    return md.str();
}

namespace {
// Extracts the body text between "## <section>" and the next "## " heading.
std::string section_body(const std::string& md, const std::string& heading) {
    const std::string tag = "## " + heading;
    size_t start = md.find(tag);
    if (start == std::string::npos) return {};
    start += tag.size();
    size_t end = md.find("\n## ", start);
    std::string body = md.substr(start, end == std::string::npos ? std::string::npos
                                                                 : end - start);
    // trim leading/trailing whitespace/newlines
    size_t b = body.find_first_not_of(" \t\n\r");
    size_t e = body.find_last_not_of(" \t\n\r");
    if (b == std::string::npos) return {};
    return body.substr(b, e - b + 1);
}

std::string meta_value(const std::string& md, const std::string& key) {
    const std::string tag = "- " + key + ": ";
    size_t start = md.find(tag);
    if (start == std::string::npos) return {};
    start += tag.size();
    size_t end = md.find('\n', start);
    return md.substr(start, end - start);
}
}  // namespace

std::optional<Card> Card::from_markdown(const std::string& md) {
    Card c;
    try {
        std::string uuid = meta_value(md, "uuid");
        if (uuid.empty()) return std::nullopt;
        c.id = EntityId::from_string(uuid);
        c.kind = entity_kind_from_string(meta_value(md, "kind"));
    } catch (...) {
        return std::nullopt;
    }
    size_t t0 = md.find("# ");
    if (t0 == 0) {
        size_t t1 = md.find('\n');
        c.title = md.substr(2, t1 - 2);
    }
    c.digest = section_body(md, "Digest");
    c.aliases = section_body(md, "Aliases");
    c.notes = section_body(md, "Notes");
    std::string rel = section_body(md, "Relations");
    std::istringstream rels(rel);
    std::string line;
    while (std::getline(rels, line)) {
        if (line.rfind("- ", 0) == 0) {
            try {
                c.relations.push_back(EntityId::from_string(line.substr(2)));
            } catch (...) {
                // tolerate non-uuid relation lines
            }
        }
    }
    return c;
}

void CardRegistry::upsert(Card c) {
    auto it = cards_.find(c.id);
    if (it != cards_.end()) {
        // Preserve free-text sections across machine regeneration.
        c.aliases = it->second.aliases.empty() ? c.aliases : it->second.aliases;
        c.notes = it->second.notes.empty() ? c.notes : it->second.notes;
    }
    cards_[c.id] = std::move(c);
}

bool CardRegistry::erase(const EntityId& id) { return cards_.erase(id) > 0; }

const Card* CardRegistry::find(const EntityId& id) const {
    auto it = cards_.find(id);
    return it == cards_.end() ? nullptr : &it->second;
}

Card* CardRegistry::find_mut(const EntityId& id) {
    auto it = cards_.find(id);
    return it == cards_.end() ? nullptr : &it->second;
}

std::vector<EntityId> CardRegistry::ids() const {
    std::vector<EntityId> out;
    out.reserve(cards_.size());
    for (const auto& [id, _] : cards_) out.push_back(id);
    return out;
}

void CardRegistry::set_alias(const EntityId& id, const std::string& text) {
    auto it = cards_.find(id);
    if (it != cards_.end()) it->second.aliases = text;
}

void CardRegistry::set_notes(const EntityId& id, const std::string& text) {
    auto it = cards_.find(id);
    if (it != cards_.end()) it->second.notes = text;
}

}  // namespace sx
