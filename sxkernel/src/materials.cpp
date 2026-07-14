#include "sx/materials.hpp"

namespace sx::materials {

const std::vector<Material>& standard() {
    static const std::vector<Material> table = {
        {"Unspecified", 1.00},
        {"ABS", 1.05},
        {"Acrylic (PMMA)", 1.19},
        {"Aluminum 6061", 2.70},
        {"Brass", 8.50},
        {"Bronze", 8.80},
        {"Cast Iron", 7.20},
        {"Copper", 8.96},
        {"Glass", 2.50},
        {"Lead", 11.34},
        {"Magnesium", 1.77},
        {"Nylon (PA6)", 1.14},
        {"Oak", 0.75},
        {"POM (Delrin)", 1.41},
        {"PVC", 1.40},
        {"Polycarbonate", 1.20},
        {"Rubber", 1.20},
        {"Stainless 304", 8.00},
        {"Steel", 7.85},
        {"Titanium Ti-6Al-4V", 4.43},
        {"Zinc", 7.14},
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
