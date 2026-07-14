#pragma once
// The Document is the root model object: bodies (OCCT shapes) plus the
// registry mapping every selectable subshape to a stable EntityId.
//
// Naming v0 (pre-Phase-3): subshape IDs are assigned on body creation by
// canonical enumeration order and persisted with the document. The real
// topological naming service (plan task 3.2) replaces the assignment
// strategy behind this same interface.

#include <TopoDS_Shape.hxx>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

#include "sx/entity.hpp"
#include "sx/ids.hpp"

namespace sx {

class CardRegistry;

struct SubshapeRef {
    EntityId body;
    EntityKind kind = EntityKind::Face;
    int index = -1;  // index in TopExp::MapShapes order for that kind
};

struct Body {
    EntityId id;
    std::string name;
    TopoDS_Shape shape;
    // Stable ids for subshapes, keyed by kind then map index (1-based, OCCT convention).
    std::map<EntityKind, std::vector<EntityId>> subshape_ids;
    std::array<float, 3> color{0.7f, 0.7f, 0.75f};
};

class Document {
public:
    Document();
    ~Document();

    // --- bodies ---
    // Registers a body: assigns EntityIds to the body and all faces/edges/vertices,
    // generates semantic cards. Returns the body id.
    EntityId add_body(const TopoDS_Shape& shape, const std::string& name);
    // Re-registers geometry for an existing body after a modeling operation,
    // reassigning subshape ids (v0: fresh ids; naming service will map them).
    void replace_body_shape(const EntityId& body, const TopoDS_Shape& shape);
    bool remove_body(const EntityId& body);

    const Body* body(const EntityId& id) const;
    Body* body_mut(const EntityId& id);
    std::vector<EntityId> body_ids() const;

    // --- entity lookup ---
    std::optional<SubshapeRef> find_subshape(const EntityId& id) const;
    // Resolve a subshape id to the actual TopoDS shape (null shape if missing).
    TopoDS_Shape resolve(const EntityId& id) const;
    std::optional<EntityId> owning_body(const EntityId& id) const;

    // Subshape id for (body, kind, 1-based index); null id if out of range.
    EntityId subshape_id(const EntityId& body, EntityKind kind, int index1) const;

    CardRegistry& cards() { return *cards_; }
    const CardRegistry& cards() const { return *cards_; }

    // Monotonic revision, bumped on every mutation (autosave/dirty tracking).
    uint64_t revision() const { return revision_; }
    void bump_revision() { ++revision_; }

    // Used by the .sxp loader to restore persisted ids exactly.
    void restore_body(Body&& b);

private:
    void register_subshapes(Body& b, bool fresh_ids);
    void regenerate_cards_for_body(const Body& b);
    void unregister_body_entities(const Body& b);

    std::vector<std::unique_ptr<Body>> bodies_;
    std::unordered_map<EntityId, size_t> body_index_;
    std::unordered_map<EntityId, SubshapeRef> subshape_index_;
    std::unique_ptr<CardRegistry> cards_;
    uint64_t revision_ = 0;
};

}  // namespace sx
