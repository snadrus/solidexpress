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
#include <variant>
#include <vector>

#include "sx/datum.hpp"
#include "sx/entity.hpp"
#include "sx/ids.hpp"
#include "sx/instances.hpp"
#include "sx/mates.hpp"

namespace sx {

class CardRegistry;
class FeatureGraph;

using Datum = std::variant<DatumPlane, DatumAxis, DatumPoint>;

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
    // Name from materials::standard(); drives density for mass readouts.
    std::string material{"Unspecified"};
};

class Document {
public:
    Document();
    ~Document();

    // --- bodies ---
    // Registers a body: assigns EntityIds to the body and all faces/edges/vertices,
    // generates semantic cards. Returns the body id. Pass `keep_id` to reuse a
    // known id (feature regeneration keeps body ids stable across rebuilds).
    EntityId add_body(const TopoDS_Shape& shape, const std::string& name,
                      const EntityId& keep_id = {});
    // Re-registers geometry for an existing body after a modeling operation,
    // reassigning subshape ids (v0: fresh ids; naming service will map them).
    void replace_body_shape(const EntityId& body, const TopoDS_Shape& shape);
    // Renames a body and refreshes its cards (body + face titles).
    bool rename_body(const EntityId& body, const std::string& name);
    // Material must be a name from materials::standard().
    bool set_body_material(const EntityId& body, const std::string& material);
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

    // Parametric timeline; regenerating it rebuilds graph-owned bodies.
    FeatureGraph& graph() { return *graph_; }
    const FeatureGraph& graph() const { return *graph_; }
    void set_graph(FeatureGraph g);

    // Monotonic revision, bumped on every mutation (autosave/dirty tracking).
    uint64_t revision() const { return revision_; }
    void bump_revision() { ++revision_; }

    // Used by the .sxp loader to restore persisted ids exactly.
    void restore_body(Body&& b);

    // --- datums (reference geometry) ---
    // Creates a datum plane through `origin` with the given `normal` (normalized
    // on insert). `x_dir` is chosen perpendicular to the normal. Returns the id.
    EntityId add_datum_plane(const std::array<double, 3>& origin,
                             const std::array<double, 3>& normal,
                             const EntityId& keep_id = {});
    EntityId add_datum_axis(const std::array<double, 3>& point,
                            const std::array<double, 3>& direction,
                            const EntityId& keep_id = {});
    EntityId add_datum_point(const std::array<double, 3>& position,
                             const EntityId& keep_id = {});
    bool remove_datum(const EntityId& id);
    const std::vector<Datum>& datums() const { return datums_; }
    // Used by the .sxp loader to restore persisted datums exactly.
    // Also upserts a semantic card for the datum (aliases/notes preserved).
    void restore_datum(Datum&& d);
    // Upserts semantic cards for every datum currently in the document.
    // Called by add_datum_* / restore_datum; .sxp loaders that write datums
    // without those APIs should call this after restore so cards exist.
    void ensure_datum_cards();

    // --- instances (assembly placements of a source body) ---
    // Semantic cards are intentionally skipped: EntityKind has no Instance
    // value and entity.hpp is owned elsewhere this round; Component exists
    // but using Body as a stand-in would be misleading. Revisit when an
    // Instance (or Component) card kind is wired end-to-end.
    EntityId add_instance(const EntityId& source_body,
                          const std::array<double, 3>& translation,
                          const std::array<double, 4>& rotation_quat,
                          const std::string& name);
    bool remove_instance(const EntityId& id);
    bool set_instance_transform(const EntityId& id,
                                const std::array<double, 3>& translation,
                                const std::array<double, 4>& rotation_quat);
    const Instance* instance(const EntityId& id) const;
    const std::vector<Instance>& instances() const { return instances_; }
    // Used by the .sxp loader to restore persisted instances exactly.
    void restore_instance(Instance&& inst);

    // --- assembly mates (see sx/mates.hpp; applied in insertion order) ---
    // Returns the mate id, or a null id when instance_b is not an instance.
    EntityId add_mate(Mate m);
    bool remove_mate(const EntityId& id);
    const std::vector<Mate>& mates() const { return mates_; }
    // Used by the .sxp loader to restore persisted mates exactly.
    void restore_mate(Mate&& m);

private:
    void register_subshapes(Body& b, bool fresh_ids);
    void regenerate_cards_for_body(const Body& b);
    void unregister_body_entities(const Body& b);
    void index_datum(Datum&& d);
    void upsert_card_for_datum(const Datum& d);

    std::vector<std::unique_ptr<Body>> bodies_;
    std::unordered_map<EntityId, size_t> body_index_;
    std::unordered_map<EntityId, SubshapeRef> subshape_index_;
    std::vector<Datum> datums_;
    std::unordered_map<EntityId, size_t> datum_index_;
    int datum_plane_seq_ = 0;
    int datum_axis_seq_ = 0;
    int datum_point_seq_ = 0;
    std::vector<Instance> instances_;
    std::unordered_map<EntityId, size_t> instance_index_;
    std::vector<Mate> mates_;
    std::unique_ptr<CardRegistry> cards_;
    std::unique_ptr<FeatureGraph> graph_;
    uint64_t revision_ = 0;
};

}  // namespace sx
