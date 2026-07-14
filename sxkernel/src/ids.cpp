#include "sx/ids.hpp"

#include <cstring>
#include <random>
#include <stdexcept>

namespace sx {

static std::mt19937_64& rng() {
    static thread_local std::mt19937_64 gen{std::random_device{}()};
    return gen;
}

EntityId EntityId::generate() {
    EntityId id;
    uint64_t a = rng()(), b = rng()();
    std::memcpy(id.bytes.data(), &a, 8);
    std::memcpy(id.bytes.data() + 8, &b, 8);
    id.bytes[6] = static_cast<uint8_t>((id.bytes[6] & 0x0F) | 0x40);  // version 4
    id.bytes[8] = static_cast<uint8_t>((id.bytes[8] & 0x3F) | 0x80);  // variant 1
    return id;
}

static int hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

EntityId EntityId::from_string(const std::string& s) {
    EntityId id;
    size_t bi = 0;
    int hi = -1;
    for (char c : s) {
        if (c == '-') continue;
        int v = hexval(c);
        if (v < 0) throw std::invalid_argument("EntityId: bad hex char");
        if (hi < 0) {
            hi = v;
        } else {
            if (bi >= 16) throw std::invalid_argument("EntityId: too long");
            id.bytes[bi++] = static_cast<uint8_t>((hi << 4) | v);
            hi = -1;
        }
    }
    if (bi != 16 || hi >= 0) throw std::invalid_argument("EntityId: bad length");
    return id;
}

std::string EntityId::str() const {
    static const char* hex = "0123456789abcdef";
    std::string out;
    out.reserve(36);
    for (size_t i = 0; i < 16; ++i) {
        if (i == 4 || i == 6 || i == 8 || i == 10) out.push_back('-');
        out.push_back(hex[bytes[i] >> 4]);
        out.push_back(hex[bytes[i] & 0xF]);
    }
    return out;
}

bool EntityId::is_null() const {
    for (auto b : bytes)
        if (b) return false;
    return true;
}

}  // namespace sx
