#pragma once
// Minimal logging until/unless we need more. Writes to stderr and an optional
// file sink. Thread-safety: single mutex, fine for current needs.

#include <string>

namespace sx::log {

enum class Level { Debug, Info, Warn, Error };

void set_file_sink(const std::string& path);  // empty disables
void write(Level lvl, const std::string& msg);

inline void debug(const std::string& m) { write(Level::Debug, m); }
inline void info(const std::string& m) { write(Level::Info, m); }
inline void warn(const std::string& m) { write(Level::Warn, m); }
inline void error(const std::string& m) { write(Level::Error, m); }

}  // namespace sx::log
