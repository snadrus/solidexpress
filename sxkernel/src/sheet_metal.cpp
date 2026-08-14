#include "sx/sheet_metal.hpp"

#include <algorithm>
#include <cmath>

namespace sx::sheet {

double bend_allowance(double angle_rad, double thickness, double k_factor, double radius) {
    return std::abs(angle_rad) * (radius + k_factor * thickness);
}

double flat_length(double leg1, double leg2, double thickness, double k_factor, double radius,
                   double angle_rad) {
    const double ba = bend_allowance(angle_rad, thickness, k_factor, radius);
    // Outside legs include the bend region once each; subtract thickness so
    // the flat is the developed inside + allowance.
    return std::max(0.0, leg1 + leg2 + ba - 2.0 * thickness);
}

void to_json(nlohmann::json& j, const FlangeParams& p) {
    j = nlohmann::json{{"length", p.length},
                       {"thickness", p.thickness},
                       {"k_factor", p.k_factor},
                       {"radius", p.radius},
                       {"angle_rad", p.angle_rad}};
}

void from_json(const nlohmann::json& j, FlangeParams& p) {
    p.length = j.value("length", 20.0);
    p.thickness = j.value("thickness", 1.5);
    p.k_factor = j.value("k_factor", 0.44);
    p.radius = j.value("radius", 1.5);
    p.angle_rad = j.value("angle_rad", 1.5707963267948966);
}

}  // namespace sx::sheet
