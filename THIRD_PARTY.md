# Third-Party Dependency Ledger

Policy: **never GPL/AGPL**. LGPL is allowed with dynamic linking only. Every dependency must be recorded here before the first commit that uses it.

| Dependency | Version | License | Linkage | Source | Notes |
|---|---|---|---|---|---|
| Open CASCADE Technology (OCCT) | 7.9.2 (Ubuntu `libocct-*-dev`) | LGPL-2.1 with OCCT exception | **Dynamic** (system `.so`) | Ubuntu archive | Geometry kernel. Prominent notice required in About/docs. |
| PlaneGCS | FreeCAD snapshot (see `thirdparty/planegcs/VENDORED_FROM.txt`) | LGPL-2.1-or-later | **Dynamic** (built as shared lib) | github.com/FreeCAD/FreeCAD `src/Mod/Sketcher/App/planegcs` | 2D constraint solver, isolated behind `SolverBackend`. |
| godot-cpp | master @ API 4.7 | MIT | Static into GDExtension | github.com/godotengine/godot-cpp | C++ bindings for GDExtension. |
| Godot Engine (editor binary, not distributed) | 4.7-stable | MIT | Tool only (`tools/godot/`, gitignored) | github.com/godotengine/godot-builds | Runtime/editor + headless test runner. |
| Eigen | 3.4.0 (Ubuntu `libeigen3-dev`) | MPL-2.0 | Header-only | Ubuntu archive | Required by PlaneGCS. |
| Boost (headers) | 1.90 (Ubuntu `libboost-dev`) | BSL-1.0 | Header-only | Ubuntu archive | `boost::graph` used by PlaneGCS diagnostics. |
| miniz | 3.0.2 | MIT | Static (vendored) | github.com/richgel999/miniz | Zip read/write for `.sxp` container. |
| nlohmann/json | 3.12.0 | MIT | Header-only (vendored) | github.com/nlohmann/json | Manifest/feature-graph JSON. |
| Catch2 | 2.13.10 (single header) | BSL-1.0 | Test-only (vendored) | github.com/catchorg/Catch2 | Kernel unit tests. |

Known banned (GPL) libraries we must NOT use: libdxfrw, Gmsh, CalculiX, Netgen-GPL variants, Qt (policy: Godot UI only).
