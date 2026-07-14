#include "sx/sxp.hpp"

#include <miniz.h>

#include <type_traits>

#include <nlohmann/json.hpp>

#include "sx/cards.hpp"
#include "sx/datum.hpp"
#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/instances.hpp"
#include "sx/log.hpp"
#include "sx/shape_utils.hpp"

using nlohmann::json;

namespace sx {

static constexpr int kFormatVersion = 1;

bool save_sxp(const Document& doc, const std::string& path, std::string* err) {
    mz_zip_archive zip{};
    if (!mz_zip_writer_init_file(&zip, path.c_str(), 0)) {
        if (err) *err = "cannot create " + path;
        return false;
    }
    auto add = [&](const std::string& name, const std::string& data) {
        return mz_zip_writer_add_mem(&zip, name.c_str(), data.data(), data.size(),
                                     MZ_DEFAULT_COMPRESSION) == MZ_TRUE;
    };

    json manifest;
    manifest["format"] = "sxp";
    manifest["version"] = kFormatVersion;
    manifest["bodies"] = json::array();

    bool ok = true;
    for (const auto& body_id : doc.body_ids()) {
        const Body* b = doc.body(body_id);
        json jb;
        jb["uuid"] = b->id.str();
        jb["name"] = b->name;
        jb["brep"] = "breps/" + b->id.str() + ".brep";
        jb["color"] = {b->color[0], b->color[1], b->color[2]};
        for (const auto& [kind, ids] : b->subshape_ids) {
            json arr = json::array();
            for (const auto& id : ids) arr.push_back(id.str());
            jb["subshapes"][to_string(kind)] = arr;
        }
        manifest["bodies"].push_back(jb);
        ok = ok && add("breps/" + b->id.str() + ".brep", shape::to_brep_string(b->shape));
    }

    for (const auto& card_id : doc.cards().ids()) {
        const Card* c = doc.cards().find(card_id);
        ok = ok && add("cards/" + card_id.str() + ".md", c->to_markdown());
    }

    json datums_json;
    datums_json["planes"] = json::array();
    datums_json["axes"] = json::array();
    datums_json["points"] = json::array();
    for (const auto& d : doc.datums()) {
        std::visit(
            [&](const auto& x) {
                using T = std::decay_t<decltype(x)>;
                if constexpr (std::is_same_v<T, DatumPlane>) {
                    datums_json["planes"].push_back(x);
                } else if constexpr (std::is_same_v<T, DatumAxis>) {
                    datums_json["axes"].push_back(x);
                } else if constexpr (std::is_same_v<T, DatumPoint>) {
                    datums_json["points"].push_back(x);
                }
            },
            d);
    }

    json instances_json = json::array();
    for (const auto& inst : doc.instances()) instances_json.push_back(inst);

    json mates_json = json::array();
    for (const auto& m : doc.mates()) mates_json.push_back(m);

    ok = ok && add("features.json", doc.graph().to_json().dump(2));
    ok = ok && add("datums.json", datums_json.dump(2));
    ok = ok && add("instances.json", instances_json.dump(2));
    ok = ok && add("mates.json", mates_json.dump(2));
    ok = ok && add("manifest.json", manifest.dump(2));
    ok = ok && mz_zip_writer_finalize_archive(&zip) == MZ_TRUE;
    mz_zip_writer_end(&zip);
    if (!ok && err) *err = "zip write failed for " + path;
    return ok;
}

static std::string read_entry(mz_zip_archive& zip, const std::string& name, bool* found) {
    int idx = mz_zip_reader_locate_file(&zip, name.c_str(), nullptr, 0);
    if (idx < 0) {
        if (found) *found = false;
        return {};
    }
    if (found) *found = true;
    size_t size = 0;
    void* p = mz_zip_reader_extract_to_heap(&zip, static_cast<mz_uint>(idx), &size, 0);
    if (!p) return {};
    std::string data(static_cast<char*>(p), size);
    mz_free(p);
    return data;
}

bool load_sxp(Document& doc, const std::string& path, std::string* err) {
    mz_zip_archive zip{};
    if (!mz_zip_reader_init_file(&zip, path.c_str(), 0)) {
        if (err) *err = "cannot open " + path;
        return false;
    }
    struct Closer {
        mz_zip_archive* z;
        ~Closer() { mz_zip_reader_end(z); }
    } closer{&zip};

    bool found = false;
    std::string manifest_text = read_entry(zip, "manifest.json", &found);
    if (!found) {
        if (err) *err = "manifest.json missing";
        return false;
    }

    json manifest;
    try {
        manifest = json::parse(manifest_text);
    } catch (const std::exception& e) {
        if (err) *err = std::string("bad manifest: ") + e.what();
        return false;
    }
    if (manifest.value("format", "") != "sxp") {
        if (err) *err = "not an sxp file";
        return false;
    }

    // Clear existing bodies before loading (also cascades instance removal).
    for (const auto& id : doc.body_ids()) doc.remove_body(id);
    {
        std::vector<EntityId> datum_ids;
        datum_ids.reserve(doc.datums().size());
        for (const auto& d : doc.datums()) {
            datum_ids.push_back(std::visit([](const auto& x) { return x.id; }, d));
        }
        for (const auto& id : datum_ids) doc.remove_datum(id);
    }
    {
        std::vector<EntityId> instance_ids;
        instance_ids.reserve(doc.instances().size());
        for (const auto& inst : doc.instances()) instance_ids.push_back(inst.id);
        for (const auto& id : instance_ids) doc.remove_instance(id);
    }
    {
        std::vector<EntityId> mate_ids;
        mate_ids.reserve(doc.mates().size());
        for (const auto& m : doc.mates()) mate_ids.push_back(m.id);
        for (const auto& id : mate_ids) doc.remove_mate(id);
    }

    try {
        for (const auto& jb : manifest["bodies"]) {
            Body b;
            b.id = EntityId::from_string(jb["uuid"].get<std::string>());
            b.name = jb.value("name", "Body");
            if (jb.contains("color")) {
                for (int i = 0; i < 3; ++i) b.color[i] = jb["color"][i].get<float>();
            }
            std::string brep = read_entry(zip, jb["brep"].get<std::string>(), &found);
            if (!found) throw std::runtime_error("missing brep for " + b.name);
            b.shape = shape::from_brep_string(brep);
            if (b.shape.IsNull()) throw std::runtime_error("bad brep for " + b.name);
            if (jb.contains("subshapes")) {
                for (const auto& [kind_name, arr] : jb["subshapes"].items()) {
                    auto& ids = b.subshape_ids[entity_kind_from_string(kind_name)];
                    for (const auto& s : arr) ids.push_back(EntityId::from_string(s.get<std::string>()));
                }
            }
            doc.restore_body(std::move(b));
        }
    } catch (const std::exception& e) {
        if (err) *err = e.what();
        return false;
    }

    // Restore the parametric feature timeline (bodies were already restored
    // exactly from BREP, so no regeneration is needed here).
    std::string features_text = read_entry(zip, "features.json", &found);
    if (found) {
        try {
            doc.set_graph(FeatureGraph::from_json(json::parse(features_text)));
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad features.json: ") + e.what());
        }
    }

    // Datums are optional for backward compatibility with older .sxp files.
    std::string datums_text = read_entry(zip, "datums.json", &found);
    if (found) {
        try {
            json dj = json::parse(datums_text);
            if (dj.contains("planes")) {
                for (const auto& jp : dj["planes"]) {
                    doc.restore_datum(Datum{jp.get<DatumPlane>()});
                }
            }
            if (dj.contains("axes")) {
                for (const auto& ja : dj["axes"]) {
                    doc.restore_datum(Datum{ja.get<DatumAxis>()});
                }
            }
            if (dj.contains("points")) {
                for (const auto& jp : dj["points"]) {
                    doc.restore_datum(Datum{jp.get<DatumPoint>()});
                }
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad datums.json: ") + e.what());
        }
    }

    // Instances are optional for backward compatibility with older .sxp files.
    std::string instances_text = read_entry(zip, "instances.json", &found);
    if (found) {
        try {
            json ij = json::parse(instances_text);
            for (const auto& ji : ij) {
                Instance inst = ji.get<Instance>();
                if (!doc.body(inst.source_body)) {
                    log::warn("sxp: dropping instance '" + inst.name +
                              "' — missing source body " + inst.source_body.str());
                    continue;
                }
                doc.restore_instance(std::move(inst));
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad instances.json: ") + e.what());
        }
    }

    // Mates are optional for backward compatibility with older .sxp files.
    std::string mates_text = read_entry(zip, "mates.json", &found);
    if (found) {
        try {
            json mj = json::parse(mates_text);
            for (const auto& jm : mj) {
                Mate m = jm.get<Mate>();
                if (!m.instance_b.is_null() && !doc.instance(m.instance_b)) {
                    log::warn("sxp: dropping mate '" + m.name +
                              "' — missing instance " + m.instance_b.str());
                    continue;
                }
                doc.restore_mate(std::move(m));
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad mates.json: ") + e.what());
        }
    }

    // Restore preserved card free-text (registered cards were regenerated by
    // restore_body; overlay aliases/notes from the archive).
    mz_uint num = mz_zip_reader_get_num_files(&zip);
    for (mz_uint i = 0; i < num; ++i) {
        char name[512];
        mz_zip_reader_get_filename(&zip, i, name, sizeof(name));
        std::string fname(name);
        if (fname.rfind("cards/", 0) != 0) continue;
        std::string md = read_entry(zip, fname, nullptr);
        auto card = Card::from_markdown(md);
        if (!card) continue;
        if (!card->aliases.empty()) doc.cards().set_alias(card->id, card->aliases);
        if (!card->notes.empty()) doc.cards().set_notes(card->id, card->notes);
    }
    return true;
}

}  // namespace sx
