#pragma once
// Sheet-metal core (Wave 2): K-factor bend allowance and flange params.
// Flat lives in the same document — split viewport, not a second file.

#include <string>

#include <nlohmann/json.hpp>

namespace sx::sheet {

// ISO-ish allowance: BA = angle * (R + K*T). Angle in radians.
double bend_allowance(double angle_rad, double thickness, double k_factor, double radius);

// Two-leg channel: L1 + L2 + BA − 2*T (outside dimensions).
double flat_length(double leg1, double leg2, double thickness, double k_factor, double radius,
                   double angle_rad = 1.5707963267948966);

struct FlangeParams {
    double length = 20.0;
    double thickness = 1.5;
    double k_factor = 0.44;
    double radius = 1.5;
    double angle_rad = 1.5707963267948966;
};

void to_json(nlohmann::json& j, const FlangeParams& p);
void from_json(const nlohmann::json& j, FlangeParams& p);

}  // namespace sx::sheet
