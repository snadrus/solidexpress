#include "sx/log.hpp"

#include <chrono>
#include <cstdio>
#include <fstream>
#include <mutex>

namespace sx::log {

namespace {
std::mutex g_mutex;
std::ofstream g_file;

const char* level_name(Level l) {
    switch (l) {
        case Level::Debug: return "DEBUG";
        case Level::Info: return "INFO";
        case Level::Warn: return "WARN";
        case Level::Error: return "ERROR";
    }
    return "?";
}
}  // namespace

void set_file_sink(const std::string& path) {
    std::lock_guard lock(g_mutex);
    if (g_file.is_open()) g_file.close();
    if (!path.empty()) g_file.open(path, std::ios::app);
}

void write(Level lvl, const std::string& msg) {
    std::lock_guard lock(g_mutex);
    auto now = std::chrono::system_clock::now().time_since_epoch();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
    char line[64];
    std::snprintf(line, sizeof(line), "[%lld] [%s] ", static_cast<long long>(ms),
                  level_name(lvl));
    std::fputs(line, stderr);
    std::fputs(msg.c_str(), stderr);
    std::fputc('\n', stderr);
    if (g_file.is_open()) g_file << line << msg << '\n' << std::flush;
}

}  // namespace sx::log
