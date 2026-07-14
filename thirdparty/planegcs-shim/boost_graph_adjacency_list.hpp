// solidexpress shim replacing FreeCAD's warning-suppressing wrapper around
// boost/graph/adjacency_list.hpp.
#pragma once
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
#include <boost/graph/adjacency_list.hpp>
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
