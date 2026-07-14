#pragma once
// Feature history graph: the parametric timeline. Features are data-driven
// (type + JSON params + optional embedded Sketch) so they serialize cleanly
// and an AI backend can read/write them as plain structured data.
//
// Regeneration (v0): replay the timeline in order, rebuilding all
// graph-owned bodies. Body ids stay stable via Feature::output_body.
// Subshape ids are re-matched positionally when the topology count is
// unchanged (naming v0.5); the topological naming service (plan task 3.2)
// upgrades this matching behind the same interface.

#include <nlohmann/json.hpp>

#include <memory>
#include <string>
#include <vector>

#include "sx/ids.hpp"
#include "sx/sketch.hpp"

namespace sx {

class Document;

enum class FeatureType {
    Primitive,  // params: {kind: "box|cylinder|sphere|cone|torus", a, b, c, origin: [x,y,z]}
    Sketch,     // embedded sketch; no geometry output
    Extrude,    // params: {sketch: <feature uuid>, distance, symmetric,
                //          op: "new|fuse|cut", target: <feature uuid, for fuse/cut>}
    Revolve,    // params: {sketch, axis_point: [u,v], axis_dir: [u,v], angle, op, target}
    Boolean,    // params: {op: "fuse|cut|common", target: <fid>, tool: <fid>}
    Fillet,     // params: {target: <fid>, radius, edges: [1-based map indices]}
    Chamfer,    // params: {target: <fid>, distance, edges: [...]}
    Mirror,     // params: {target: <fid>, plane_point: [x,y,z], plane_normal: [x,y,z]}
    LinearPattern,   // params: {target, direction: [x,y,z], spacing, count}
    CircularPattern, // params: {target, axis_point, axis_dir, count, total_angle}
    Shell,      // params: {target, faces: [1-based face indices], thickness}
    Offset,     // params: {target, offset}
    Sweep,      // params: {sketch: <fid>, path: [[x,y,z], ...]}
    Loft,       // params: {sketches: [<fid>, ...], ruled: bool}
};

const char* to_string(FeatureType t);
FeatureType feature_type_from_string(const std::string& s);

struct Feature {
    EntityId id;
    std::string name;
    FeatureType type = FeatureType::Primitive;
    bool suppressed = false;
    nlohmann::json params;
    std::shared_ptr<Sketch> sketch;  // only for FeatureType::Sketch
    // Stable id of the body this feature creates (Primitive, new-body
    // Extrude/Revolve, Mirror, Sweep, Loft). Null for sketches and modifying
    // features.
    EntityId output_body;
    // Stable ids of additional bodies created by pattern features
    // (count-1 copies). Empty for all other types.
    std::vector<EntityId> output_bodies;
};

class FeatureGraph {
public:
    // Appends to the timeline. Assigns feature id (and output_body id where
    // applicable) if unset. Returns the feature id.
    EntityId add(Feature f);
    bool remove(const EntityId& id);  // fails if a later feature references it
    bool set_suppressed(const EntityId& id, bool suppressed);
    // Update params and regenerate later; returns false if feature missing.
    bool set_params(const EntityId& id, nlohmann::json params);

    Feature* feature(const EntityId& id);
    const Feature* feature(const EntityId& id) const;
    const std::vector<Feature>& timeline() const { return timeline_; }

    // True if any later feature references `id` in its params.
    bool has_dependents(const EntityId& id) const;

    // Full rebuild: removes all graph-owned bodies from the document and
    // replays the timeline. On failure, err names the offending feature and
    // the document is left with features applied up to that point.
    bool regenerate(Document& doc, std::string* err = nullptr);

    nlohmann::json to_json() const;
    static FeatureGraph from_json(const nlohmann::json& j);

private:
    bool apply(Document& doc, Feature& f, std::string* err);
    std::vector<Feature> timeline_;
    // Body ids created by the last regenerate. Needed so bodies belonging to
    // features that were since removed from the timeline still get cleaned up.
    std::vector<EntityId> generated_;
};

}  // namespace sx
