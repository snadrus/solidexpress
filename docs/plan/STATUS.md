# solidexpress build status

Updated by agents on every merge. See `docs/plan/implementation-plan.md` for task definitions.

## Phase 0 — Foundation
- [x] 0.1 Repo layout + CMake superbuild + THIRD_PARTY.md (OCCT 7.9.2 system, godot-cpp master pinned to 4.7-stable API dump, PlaneGCS vendored from FreeCAD + shim headers, miniz, nlohmann/json, Catch2)
- [x] 0.2 sxkernel scaffold: Document, Body, EntityId (UUIDv4), undo/redo CommandStack; commands: AddPrimitive, DeleteBody, TranslateBody, PushPull
- [x] 0.3 Semantic card registry v1: MD generation + parsing, free-text (Aliases/Notes) preserved across regeneration
- [x] 0.4 Tessellation service (OCCT BRepMesh → raw buffers) + ArrayMesh bridge (one surface per face, edge polylines)
- [x] 0.5 Exact B-rep ray picking with stable face UUIDs (kernel + Godot `pick()`)
- [x] 0.6 `.sxp` container (miniz zip: manifest.json + breps + cards), UUID-stable round trip
- [x] 0.7 Headless Godot test runner (`game/tests/run_tests.gd`), `make test` (kernel Catch2 + Godot integration)
- [ ] 0.8 Autosave stub + config file (logging done via `sx::log`)

Test state: `make test` → kernel 24 cases / 5373 assertions PASS; Godot integration 33 checks PASS.

## Phase 1 — Drag-and-drop shell
- [ ] 1.1 Viewport navigation (orbit/pan/zoom, grid, axes)
- [ ] 1.2 Primitive palette with drag-and-drop insert
- [ ] 1.3 Selection (click faces/bodies, highlight, property panel showing card)
- [ ] 1.4 Move gizmo (axis translate)
- [ ] 1.5 Push/pull face interaction
- [ ] 1.6 Undo/redo/delete/save/load wired to UI

## Later phases
Not started. See implementation plan.

## Environment notes
- System deps installed via apt: ninja-build, zip, libocct-*-dev (7.9.2), libeigen3-dev, libboost-dev
- Godot 4.7-stable binary at `tools/godot/godot` (gitignored; re-download from godot-builds if missing)
- Build: `make build` (CMake+Ninja superbuild, ~5 min cold for godot-cpp)
- PlaneGCS builds as `libplanegcs.so` (LGPL dynamic-link compliance); not yet consumed by sxkernel (Phase 2)
