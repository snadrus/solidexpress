#include "sx/thread_standards.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <string>

namespace sx {
namespace {

constexpr double kIsoHalfDepth = 0.6134;
constexpr double kInchToMm = 25.4;
constexpr double kEps = 1e-9;

std::string trim_copy(std::string s) {
    auto not_space = [](unsigned char c) { return !std::isspace(c); };
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), not_space));
    s.erase(std::find_if(s.rbegin(), s.rend(), not_space).base(), s.end());
    return s;
}

std::string to_upper(std::string s) {
    for (char& c : s) {
        c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    }
    return s;
}

double inch_to_mm(double inches) {
    return inches * kInchToMm;
}

double pitch_from_tpi(int tpi) {
    return kInchToMm / static_cast<double>(tpi);
}

ThreadSpec make_metric(const std::string& designation, double major_mm, double pitch_mm) {
    return ThreadSpec{designation, major_mm, pitch_mm, false};
}

ThreadSpec make_imperial(const std::string& designation, double major_in, int tpi) {
    return ThreadSpec{designation, inch_to_mm(major_in), pitch_from_tpi(tpi), false};
}

const std::vector<ThreadSpec>& table() {
    static const std::vector<ThreadSpec> kTable = {
        // ISO metric coarse (ISO 261 / 262)
        make_metric("M2", 2.0, 0.4),
        make_metric("M2.5", 2.5, 0.45),
        make_metric("M3", 3.0, 0.5),
        make_metric("M4", 4.0, 0.7),
        make_metric("M5", 5.0, 0.8),
        make_metric("M6", 6.0, 1.0),
        make_metric("M8", 8.0, 1.25),
        make_metric("M10", 10.0, 1.5),
        make_metric("M12", 12.0, 1.75),
        make_metric("M16", 16.0, 2.0),
        make_metric("M20", 20.0, 2.5),
        make_metric("M24", 24.0, 3.0),
        make_metric("M30", 30.0, 3.5),

        // ISO metric fine
        make_metric("M8x1.0", 8.0, 1.0),
        make_metric("M10x1.25", 10.0, 1.25),
        make_metric("M12x1.25", 12.0, 1.25),
        make_metric("M12x1.5", 12.0, 1.5),
        make_metric("M16x1.5", 16.0, 1.5),
        make_metric("M20x1.5", 20.0, 1.5),
        make_metric("M24x2.0", 24.0, 2.0),

        // UNC (ASME B1.1) — major diameters in inches
        make_imperial("#4-40 UNC", 0.112, 40),
        make_imperial("#6-32 UNC", 0.138, 32),
        make_imperial("#8-32 UNC", 0.164, 32),
        make_imperial("#10-24 UNC", 0.190, 24),
        make_imperial("1/4-20 UNC", 0.250, 20),
        make_imperial("5/16-18 UNC", 0.3125, 18),
        make_imperial("3/8-16 UNC", 0.375, 16),
        make_imperial("1/2-13 UNC", 0.500, 13),

        // UNF (ASME B1.1)
        make_imperial("#10-32 UNF", 0.190, 32),
        make_imperial("1/4-28 UNF", 0.250, 28),
        make_imperial("5/16-24 UNF", 0.3125, 24),
        make_imperial("3/8-24 UNF", 0.375, 24),
        make_imperial("1/2-20 UNF", 0.500, 20),
    };
    return kTable;
}

bool near(double a, double b) {
    return std::fabs(a - b) <= kEps;
}

// Parse leading double; returns true and advances *pos on success.
bool parse_double(const std::string& s, size_t* pos, double* out) {
    if (*pos >= s.size()) {
        return false;
    }
    char* end = nullptr;
    const char* start = s.c_str() + *pos;
    *out = std::strtod(start, &end);
    if (end == start) {
        return false;
    }
    *pos = static_cast<size_t>(end - s.c_str());
    return true;
}

bool parse_int(const std::string& s, size_t* pos, int* out) {
    if (*pos >= s.size() || !std::isdigit(static_cast<unsigned char>(s[*pos]))) {
        return false;
    }
    char* end = nullptr;
    const char* start = s.c_str() + *pos;
    long v = std::strtol(start, &end, 10);
    if (end == start) {
        return false;
    }
    *out = static_cast<int>(v);
    *pos = static_cast<size_t>(end - s.c_str());
    return true;
}

enum class Series { None, Unc, Unf };

struct ParsedMetric {
    double major_mm = 0.0;
    bool has_pitch = false;
    double pitch_mm = 0.0;
};

struct ParsedImperial {
    std::string size_key;  // "#10-32" or "1/4-20"
    Series series = Series::None;
};

std::optional<ParsedMetric> try_parse_metric(const std::string& s) {
    if (s.empty() || s[0] != 'M') {
        return std::nullopt;
    }
    size_t pos = 1;
    ParsedMetric m;
    if (!parse_double(s, &pos, &m.major_mm)) {
        return std::nullopt;
    }
    if (pos == s.size()) {
        return m;
    }
    if (s[pos] != 'X') {
        return std::nullopt;
    }
    ++pos;
    if (!parse_double(s, &pos, &m.pitch_mm) || pos != s.size()) {
        return std::nullopt;
    }
    m.has_pitch = true;
    return m;
}

std::optional<ParsedImperial> try_parse_imperial(const std::string& s) {
    ParsedImperial imp;
    size_t pos = 0;

    if (s[0] == '#') {
        ++pos;
        int gauge = 0;
        int tpi = 0;
        if (!parse_int(s, &pos, &gauge)) {
            return std::nullopt;
        }
        if (pos >= s.size() || s[pos] != '-') {
            return std::nullopt;
        }
        ++pos;
        if (!parse_int(s, &pos, &tpi)) {
            return std::nullopt;
        }
        imp.size_key = "#" + std::to_string(gauge) + "-" + std::to_string(tpi);
    } else {
        int num = 0;
        int den = 0;
        int tpi = 0;
        if (!parse_int(s, &pos, &num)) {
            return std::nullopt;
        }
        if (pos >= s.size() || s[pos] != '/') {
            return std::nullopt;
        }
        ++pos;
        if (!parse_int(s, &pos, &den) || den == 0) {
            return std::nullopt;
        }
        if (pos >= s.size() || s[pos] != '-') {
            return std::nullopt;
        }
        ++pos;
        if (!parse_int(s, &pos, &tpi)) {
            return std::nullopt;
        }
        imp.size_key = std::to_string(num) + "/" + std::to_string(den) + "-" + std::to_string(tpi);
    }

    if (pos < s.size()) {
        if (s[pos] != ' ') {
            return std::nullopt;
        }
        ++pos;
        const std::string rest = s.substr(pos);
        if (rest == "UNC") {
            imp.series = Series::Unc;
        } else if (rest == "UNF") {
            imp.series = Series::Unf;
        } else {
            return std::nullopt;
        }
    }
    return imp;
}

bool is_coarse_metric_designation(const std::string& designation) {
    // Coarse entries are "M…" with no 'x' pitch suffix.
    return designation.size() >= 2 && designation[0] == 'M' &&
           designation.find('x') == std::string::npos && designation.find('X') == std::string::npos;
}

std::optional<ThreadSpec> find_metric(const ParsedMetric& m) {
    const auto& t = table();
    if (!m.has_pitch) {
        for (const auto& e : t) {
            if (is_coarse_metric_designation(e.designation) && near(e.major_diameter_mm, m.major_mm)) {
                return e;
            }
        }
        return std::nullopt;
    }
    for (const auto& e : t) {
        if (e.designation.empty() || e.designation[0] != 'M') {
            continue;
        }
        if (near(e.major_diameter_mm, m.major_mm) && near(e.pitch_mm, m.pitch_mm)) {
            return e;
        }
    }
    return std::nullopt;
}

bool ends_with_series(const std::string& designation, const char* series) {
    const std::string suffix = std::string(" ") + series;
    return designation.size() >= suffix.size() &&
           designation.compare(designation.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::optional<ThreadSpec> find_imperial(const ParsedImperial& imp) {
    const auto& t = table();
    std::optional<ThreadSpec> unc_match;
    std::optional<ThreadSpec> unf_match;

    for (const auto& e : t) {
        // Match size key as a prefix of the stored designation ("1/4-20 UNC").
        if (e.designation.compare(0, imp.size_key.size(), imp.size_key) != 0) {
            continue;
        }
        if (e.designation.size() > imp.size_key.size() && e.designation[imp.size_key.size()] != ' ') {
            continue;
        }
        if (ends_with_series(e.designation, "UNC")) {
            unc_match = e;
        } else if (ends_with_series(e.designation, "UNF")) {
            unf_match = e;
        }
    }

    if (imp.series == Series::Unc) {
        return unc_match;
    }
    if (imp.series == Series::Unf) {
        return unf_match;
    }
    // Series omitted: prefer UNC when both (or either) match.
    if (unc_match) {
        return unc_match;
    }
    return unf_match;
}

}  // namespace

double ThreadSpec::minor_diameter_mm() const {
    return major_diameter_mm - 2.0 * kIsoHalfDepth * pitch_mm;
}

double ThreadSpec::thread_depth_mm() const {
    return kIsoHalfDepth * pitch_mm;
}

const std::vector<ThreadSpec>& thread_table() {
    return table();
}

std::optional<ThreadSpec> find_thread(const std::string& designation) {
    const std::string norm = to_upper(trim_copy(designation));
    if (norm.empty()) {
        return std::nullopt;
    }

    if (auto metric = try_parse_metric(norm)) {
        return find_metric(*metric);
    }
    if (auto imperial = try_parse_imperial(norm)) {
        return find_imperial(*imperial);
    }
    return std::nullopt;
}

}  // namespace sx
