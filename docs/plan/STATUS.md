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
- [x] 0.8 Autosave (60 s timer in main.gd, revision-gated, `user://autosave.sxp`); logging via `sx::log`

Test state: `make test` → kernel 24 cases / 5373 assertions PASS; Godot integration 33 checks PASS; Phase 1 shell 33 checks PASS.

## Phase 1 — Drag-and-drop shell
- [x] 1.1 Viewport navigation: OrbitCamera (middle-drag orbit, shift+middle pan, wheel zoom, F frame), grid + axes, Z-up ModelSpace mapping kernel frame to Godot Y-up
- [x] 1.2 Primitive palette (box/cylinder/sphere/cone/torus) with Godot drag-and-drop onto viewport + click-to-insert
- [x] 1.3 Selection: click = body, second click = face; per-face highlight materials; card panel (RichTextLabel) shows semantic card of selection
- [x] 1.4 Move: drag selected body on ground plane (live preview, kernel commit on release) — axis gizmo still TODO
- [x] 1.5 Push/pull: drag a selected face along its normal (ray-line closest-approach math), planar faces v0
- [x] 1.6 Undo/redo (Ctrl+Z/Y), delete (Del), save/load (Ctrl+S/O) wired; status bar hints
- [ ] 1.7 Move gizmo with per-axis constraints (follow-up)

Key files: `game/scripts/document_view.gd` (view-model), `viewport_interaction.gd` (input), `orbit_camera.gd`, `palette_button.gd`, `main.gd` (composition root). Tests: `game/tests/run_ui_tests.gd`.

## Phase 2 — Sketching + solver
- [x] 2.1 Sketch model: Point/Line/Circle/Arc entities, 11 constraint types, stable param storage (`sx/sketch.hpp`)
- [x] 2.2 SolverBackend seam (`sx/solver.hpp`) + PlaneGCS backend (DogLeg, diagnostics: dofs/conflicting/redundant) — AI-first backend plugs in here later
- [x] 2.3 Profile→face builder (closed loop chaining of lines/arcs, circle→disk, construction geometry excluded)
- [x] 2.4 Extrude (incl. symmetric) + Revolve commands, undoable, snapshot pattern
- [x] 2.5 SxSketch GDExtension binding (entities, constraints, solve, entity_info snapshots) + `SxDocument.extrude_sketch/revolve_sketch`
- [x] 2.6 Sketch mode UI v1: sketch on ground plane or selected planar face; line-chain/rect/circle tools with live preview; toolbar with extrude distance; Esc cancel (`game/scripts/sketch_mode.gd`) — constraint toolbar + dimension input still TODO
- [ ] 2.7 Sketch persistence in .sxp + semantic cards for sketch entities

Test state additions: kernel [sketch]+[extrude] 14 cases; Godot sketch binding 23 checks PASS (parametric re-solve verified).

## Modeling operations (delivered by parallel agents, merged)
- [x] Booleans: BooleanCommand fuse/cut/common with keep_tool option, snapshot undo/redo ([booleans], 5 cases)
- [x] Fillet + chamfer: FilletCommand/ChamferCommand on edge id lists ([dress], 4 cases). Note: chamfer d=2 on 10mm edge removes 0.5·d²·L → volume ≈980
- [x] Interop: STEP/IGES/STL import+export in `sx/interop.hpp` ([interop], 4 cases). Quirks: StlAPI ASCIIMode() true=ASCII; IGES imports often shells not solids

Kernel suite now 51 cases / 5492 assertions.

## Later phases
Not started. See implementation plan.

## Environment notes
- System deps installed via apt: ninja-build, zip, libocct-*-dev (7.9.2), libeigen3-dev, libboost-dev
- Godot 4.7-stable binary at `tools/godot/godot` (gitignored; re-download from godot-builds if missing)
- Build: `make build` (CMake+Ninja superbuild, ~5 min cold for godot-cpp)
- PlaneGCS builds as `libplanegcs.so` (LGPL dynamic-link compliance); not yet consumed by sxkernel (Phase 2)
