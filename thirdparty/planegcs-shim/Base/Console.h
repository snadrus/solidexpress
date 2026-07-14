// solidexpress shim replacing FreeCAD's Base::Console() logger for standalone
// PlaneGCS builds. Routes solver diagnostics to stderr.
#pragma once

#include <cstdarg>
#include <cstdio>

namespace Base {

class ConsoleSingleton {
public:
    void log(const char* fmt, ...) {
        va_list args;
        va_start(args, fmt);
        vfprintf(stderr, fmt, args);
        va_end(args);
    }
    void warning(const char* fmt, ...) {
        va_list args;
        va_start(args, fmt);
        fprintf(stderr, "[planegcs warning] ");
        vfprintf(stderr, fmt, args);
        va_end(args);
    }
    void error(const char* fmt, ...) {
        va_list args;
        va_start(args, fmt);
        fprintf(stderr, "[planegcs error] ");
        vfprintf(stderr, fmt, args);
        va_end(args);
    }
    void message(const char* fmt, ...) {
        va_list args;
        va_start(args, fmt);
        vfprintf(stderr, fmt, args);
        va_end(args);
    }
};

inline ConsoleSingleton& Console() {
    static ConsoleSingleton instance;
    return instance;
}

}  // namespace Base
