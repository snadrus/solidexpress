#pragma once
// JSON (de)serialization for Sketch — used by the feature graph (extrude
// features embed their sketch) and by .sxp persistence.

#include <nlohmann/json.hpp>

#include "sx/sketch.hpp"

namespace sx {

nlohmann::json sketch_to_json(const Sketch& sk);
// Reconstructs a sketch (entity/constraint ids are preserved).
std::shared_ptr<Sketch> sketch_from_json(const nlohmann::json& j);

}  // namespace sx
