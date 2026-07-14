#pragma once
// Semantic cards (plan §3): one Markdown card per selectable entity.
// Machine sections ("Digest", "Relations") are regenerated on rebuild;
// free-text sections ("Aliases", "Notes") are preserved verbatim so users
// and AI can attach arbitrary language to any entity.

#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

#include "sx/entity.hpp"
#include "sx/ids.hpp"

namespace sx {

struct Card {
    EntityId id;
    EntityKind kind = EntityKind::Body;
    std::string title;              // human-readable, e.g. "Face 3 of Box 1"
    std::string digest;             // machine-generated geometric summary (markdown body)
    std::vector<EntityId> relations;  // related entities (owner body, adjacent faces...)
    std::string aliases;            // preserved free text
    std::string notes;              // preserved free text

    std::string to_markdown() const;
    // Parses a card MD file; returns nullopt on malformed input.
    static std::optional<Card> from_markdown(const std::string& md);
};

class CardRegistry {
public:
    // Creates or regenerates the machine sections of a card, preserving any
    // existing aliases/notes for the same EntityId.
    void upsert(Card c);
    bool erase(const EntityId& id);
    const Card* find(const EntityId& id) const;
    Card* find_mut(const EntityId& id);
    size_t size() const { return cards_.size(); }
    std::vector<EntityId> ids() const;

    void set_alias(const EntityId& id, const std::string& text);
    void set_notes(const EntityId& id, const std::string& text);

private:
    std::unordered_map<EntityId, Card> cards_;
};

}  // namespace sx
