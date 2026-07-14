#pragma once
// Stable entity identity. Every selectable thing in solidexpress has an
// EntityId that survives regeneration and serialization (plan §3).

#include <array>
#include <cstdint>
#include <cstring>
#include <functional>
#include <string>

namespace sx {

struct EntityId {
    std::array<uint8_t, 16> bytes{};

    static EntityId generate();                    // random v4 UUID
    static EntityId from_string(const std::string& s);  // parses canonical hex form
    std::string str() const;                       // "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

    bool is_null() const;
    bool operator==(const EntityId& o) const { return bytes == o.bytes; }
    bool operator!=(const EntityId& o) const { return bytes != o.bytes; }
    bool operator<(const EntityId& o) const { return bytes < o.bytes; }
};

}  // namespace sx

template <>
struct std::hash<sx::EntityId> {
    size_t operator()(const sx::EntityId& id) const noexcept {
        uint64_t a, b;
        std::memcpy(&a, id.bytes.data(), 8);
        std::memcpy(&b, id.bytes.data() + 8, 8);
        return std::hash<uint64_t>{}(a ^ (b * 0x9E3779B97F4A7C15ull));
    }
};
