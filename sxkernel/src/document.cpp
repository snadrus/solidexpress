#include "sx/document.hpp"

#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

#include "sx/cards.hpp"
#include "sx/shape_utils.hpp"

namespace sx {

Document::Document() : cards_(std::make_unique<CardRegistry>()) {}
Document::~Document() = default;

static const std::array<std::pair<EntityKind, TopAbs_ShapeEnum>, 3> kSubKinds = {{
    {EntityKind::Face, TopAbs_FACE},
    {EntityKind::Edge, TopAbs_EDGE},
    {EntityKind::Vertex, TopAbs_VERTEX},
}};

EntityId Document::add_body(const TopoDS_Shape& shape, const std::string& name) {
    auto b = std::make_unique<Body>();
    b->id = EntityId::generate();
    b->name = name;
    b->shape = shape;
    register_subshapes(*b, /*fresh_ids=*/true);

    Body* raw = b.get();
    body_index_[b->id] = bodies_.size();
    bodies_.push_back(std::move(b));
    regenerate_cards_for_body(*raw);
    bump_revision();
    return raw->id;
}

void Document::restore_body(Body&& body) {
    auto b = std::make_unique<Body>(std::move(body));
    register_subshapes(*b, /*fresh_ids=*/false);
    Body* raw = b.get();
    body_index_[b->id] = bodies_.size();
    bodies_.push_back(std::move(b));
    regenerate_cards_for_body(*raw);
    bump_revision();
}

void Document::replace_body_shape(const EntityId& body_id, const TopoDS_Shape& shape) {
    Body* b = body_mut(body_id);
    if (!b) return;
    unregister_body_entities(*b);
    b->shape = shape;
    b->subshape_ids.clear();
    register_subshapes(*b, /*fresh_ids=*/true);
    regenerate_cards_for_body(*b);
    bump_revision();
}

bool Document::remove_body(const EntityId& body_id) {
    auto it = body_index_.find(body_id);
    if (it == body_index_.end()) return false;
    size_t idx = it->second;
    unregister_body_entities(*bodies_[idx]);
    cards_->erase(body_id);
    bodies_.erase(bodies_.begin() + static_cast<long>(idx));
    body_index_.erase(it);
    // Reindex the remaining bodies.
    for (size_t i = idx; i < bodies_.size(); ++i) body_index_[bodies_[i]->id] = i;
    bump_revision();
    return true;
}

const Body* Document::body(const EntityId& id) const {
    auto it = body_index_.find(id);
    return it == body_index_.end() ? nullptr : bodies_[it->second].get();
}

Body* Document::body_mut(const EntityId& id) {
    auto it = body_index_.find(id);
    return it == body_index_.end() ? nullptr : bodies_[it->second].get();
}

std::vector<EntityId> Document::body_ids() const {
    std::vector<EntityId> out;
    out.reserve(bodies_.size());
    for (const auto& b : bodies_) out.push_back(b->id);
    return out;
}

std::optional<SubshapeRef> Document::find_subshape(const EntityId& id) const {
    auto it = subshape_index_.find(id);
    if (it == subshape_index_.end()) return std::nullopt;
    return it->second;
}

TopoDS_Shape Document::resolve(const EntityId& id) const {
    if (const Body* b = body(id)) return b->shape;
    auto ref = find_subshape(id);
    if (!ref) return {};
    const Body* b = body(ref->body);
    if (!b) return {};
    TopAbs_ShapeEnum occt_kind = TopAbs_FACE;
    for (const auto& [kind, abs] : kSubKinds)
        if (kind == ref->kind) occt_kind = abs;
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(b->shape, occt_kind, map);
    if (ref->index < 1 || ref->index > map.Extent()) return {};
    return map(ref->index);
}

std::optional<EntityId> Document::owning_body(const EntityId& id) const {
    if (body(id)) return id;
    auto ref = find_subshape(id);
    if (!ref) return std::nullopt;
    return ref->body;
}

EntityId Document::subshape_id(const EntityId& body_id, EntityKind kind, int index1) const {
    const Body* b = body(body_id);
    if (!b) return {};
    auto found = b->subshape_ids.find(kind);
    if (found == b->subshape_ids.end()) return {};
    if (index1 < 1 || static_cast<size_t>(index1) > found->second.size()) return {};
    return found->second[static_cast<size_t>(index1 - 1)];
}

void Document::register_subshapes(Body& b, bool fresh_ids) {
    for (const auto& [kind, abs] : kSubKinds) {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(b.shape, abs, map);
        auto& ids = b.subshape_ids[kind];
        if (fresh_ids || static_cast<int>(ids.size()) != map.Extent()) {
            ids.clear();
            ids.reserve(static_cast<size_t>(map.Extent()));
            for (int i = 0; i < map.Extent(); ++i) ids.push_back(EntityId::generate());
        }
        for (int i = 1; i <= map.Extent(); ++i) {
            subshape_index_[ids[static_cast<size_t>(i - 1)]] =
                SubshapeRef{b.id, kind, i};
        }
    }
}

void Document::unregister_body_entities(const Body& b) {
    for (const auto& [kind, ids] : b.subshape_ids) {
        for (const auto& id : ids) {
            subshape_index_.erase(id);
            cards_->erase(id);
        }
    }
}

void Document::regenerate_cards_for_body(const Body& b) {
    Card bc;
    bc.id = b.id;
    bc.kind = EntityKind::Body;
    bc.title = b.name;
    auto tc = shape::count(b.shape);
    bc.digest = "solid body `" + b.name + "` with " + std::to_string(tc.faces) +
                " faces, " + std::to_string(tc.edges) + " edges, volume " +
                std::to_string(shape::volume(b.shape)) + " mm^3";
    cards_->upsert(std::move(bc));

    // Face cards (edges/vertices get cards lazily later; faces are the primary
    // selectable for the drag-and-drop phase).
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b.shape, TopAbs_FACE, faces);
    const auto& face_ids = b.subshape_ids.at(EntityKind::Face);
    for (int i = 1; i <= faces.Extent(); ++i) {
        Card fc;
        fc.id = face_ids[static_cast<size_t>(i - 1)];
        fc.kind = EntityKind::Face;
        fc.title = "Face " + std::to_string(i) + " of " + b.name;
        fc.digest = shape::describe_face(faces(i));
        fc.relations = {b.id};
        cards_->upsert(std::move(fc));
    }
}

}  // namespace sx
