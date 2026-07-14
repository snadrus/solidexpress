#pragma once
// ISO metric (coarse/fine) and UNC/UNF thread designation lookup.
// Converts strings like "M8x1.25" or "1/4-20 UNC" into numeric ThreadSpec
// parameters for the modeled Thread feature.

#include <optional>
#include <string>
#include <vector>

namespace sx {

struct ThreadSpec {
    std::string designation;   // "M8", "M8x1.0", "1/4-20 UNC"
    double major_diameter_mm;  // nominal major diameter in mm
    double pitch_mm;           // thread pitch in mm (for UNC/UNF: 25.4 / TPI)
    bool internal;             // caller sets; table entries default false

    // ISO 60° V-thread geometry helpers.
    double minor_diameter_mm() const;  // major - 2 * 0.6134 * pitch
    double thread_depth_mm() const;    // 0.6134 * pitch
};

// Case-insensitive lookup. Accepts "M8" (coarse default), "M8x1" / "M8x1.0"
// (fine), and imperial "1/4-20", "1/4-20 UNC", "#10-32 UNF" forms.
// Returns std::nullopt for unknown designations.
std::optional<ThreadSpec> find_thread(const std::string& designation);

// All table entries, for populating a UI dropdown.
const std::vector<ThreadSpec>& thread_table();

}  // namespace sx
