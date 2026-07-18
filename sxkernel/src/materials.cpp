#include "sx/materials.hpp"

namespace sx::materials {

const std::vector<Material>& standard() {
    static const std::vector<Material> table = {
        {"Unspecified", 1.00},
        {"Aluminum", 2.70},
        {"Cobalt Chrome", 8.30},
        {"Copper", 8.96},
        {"Inconel", 8.44},
        {"Nylon", 1.14},
        {"PC", 1.20},
        {"PLA", 1.24},
        {"PPA", 1.20},
        {"Stainless Steel", 8.00},
        {"Titanium", 4.43},
        {"Tool Steel", 8.05},
        {"TPU", 1.21},
    };
    return table;
}

std::optional<Material> find(const std::string& name) {
    for (const auto& m : standard()) {
        if (m.name == name) return m;
    }
    return std::nullopt;
}

}  // namespace sx::materials
