#pragma once
// Standard material table: display name + density. Bodies reference a
// material by name; density drives mass in measure::mass_properties users.

#include <optional>
#include <string>
#include <vector>

namespace sx::materials {

struct Material {
    std::string name;
    double density_g_cm3 = 1.0;
};

// Common printable materials (FDM filament + metal AM), alphabetical.
// The first entry is the "Unspecified" default (density 1.0 so mass ==
// volume/1000 in grams).
const std::vector<Material>& standard();

std::optional<Material> find(const std::string& name);

}  // namespace sx::materials
