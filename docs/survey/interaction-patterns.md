# Interaction Patterns Survey (Visual UX)

Companion to the [feature survey](README.md). That catalog asks *what* products can do; this note asks *how users discover and drive* those actions — especially patterns that are **visible on or next to geometry**.

SolidExpress principle: prefer geometry-attached affordances over dock-only or shortcut-only paths.

## Shared peer patterns

| Pattern | SolidWorks | Fusion | Onshape | Shapr3D / direct-manip tools | SolidExpress |
|---|---|---|---|---|---|
| Hover pre-highlight | Yes | Yes | Yes | Yes | Yes (visual-UX slice) |
| Selection tint / frame | Yes | Yes | Yellow highlight | Clear selection + gizmo | Tint + AABB corners |
| ViewCube / view selector | View Selector | ViewCube | View cube | Orientation tools | ViewWidget |
| Empty / MMB orbit | MMB | Presets (MMB/Shift) | Configurable | Gestures | Empty-LMB, Alt, MMB, two-finger |
| Drag-handle editing | Dim / triad | Push/Pull arrow | Face drag | Move gizmo | Resize handles, XYZ move, face arrow |
| Live edit preview | Yes | Yes | Yes | Yes | Live push/pull + move nudge |
| Selection-aware tools | Context menu | Marking menu | S toolbox | Adaptive UI | RMB menu + selection strip |
| Gesture vs dock scroll | Native | Native | Browser-native | Tablet-native | Pan/wheel ignored over ScrollContainers |
| Place ghost + snap | Mate preview etc. | Insert preview | Mate connector cues | Snap grid | Place ghost + snap bar |
| Fit selection | Zoom to selection | Fit preferred selection | Fit | Frame | F / double-MMB — selection first |
| RMB drag vs click | Configurable | Marking vs orbit schemes | Configurable | Often orbit | RMB-drag orbit; click = menu |
| Nav presets | Fixed SW-like | Multi-preset | Configurable | Fixed | ViewHud: SX / SW / Fusion |
| Space orientation | Spacebar View Orientation | Views | S toolbox | — | Space popup (views + fit + User) |
| Rollback / history scrub | Rollback bar | Timeline scrubber | Rollback bar | — | Draggable `═══ rollback ═══` row (undoable, persisted) |
| Regen failure marks | Red ! on tree row | Warning icons | Error flags | — | Red `!` badge + tooltip on the timeline row |
| Feature icons + drag reorder | Yes | Yes | Yes | — | Type icons on rows; drag rows to reorder (blocked = red flash) |
| Constraint glyphs | Relation badges | Show constraints | Constraint icons | Minimal | H/V/∥/⊥/=/◉ badges; click + Del removes |
| DOF / constrained state | Under/fully defined text | — | Blue→black entities | — | Toolbar DOF chip + whole-sketch green; conflicts red |
| Click-to-edit dimension | Double-click dim | Edit dim | Double-click dim | Direct value | Click dim label → in-place editor |
| Live relation inference cue | Yellow relation preview | Snap glyphs | Inference dots | Snap cues | Yellow H/V/◉ hint at the cursor while drawing |
| Drag instance + mate snap | Drag with mates | Drag + joints pull | Drag | Direct drag | Instance drag on ground plane; `solve_mates` re-snap on release |
| Mate pick feedback | Face highlights | Joint glyphs | Mate connector cues | — | Anchor face stays green until second pick; errors badge the panel |

## Workflows peers make obvious

1. **Hover → select → manipulate** — The cursor always advertises the next pick (body/face/edge). Selected state is stronger and distinct from hover. Handles appear on the selection.
2. **Nearby verbs** — After selecting a face/edge/body, Extrude / Fillet / Hide / Delete appear on RMB or a thin strip, not only in a far dock.
3. **Camera without a middle button** — Empty-drag, Alt-drag, or trackpad pan; ViewCube for snapped views.
4. **Numbers where you drag** — A live mm badge travels with push/pull / resize; typed precision is optional after release.
5. **View chrome** — Display mode / section / fit are buttons beside the ViewCube, mirrored by shortcuts.

## SolidExpress mapping

| Peer cue | SX implementation |
|---|---|
| Hover ≠ selection | `DocumentView.set_hover` + hover materials |
| Body drag move | Drag selected mesh on active plane; rotate arcs + stretch grips; editable Δ (ΔZ typed only) |
| Face pull | Normal arrow + live kernel push/pull while dragging |
| Resize corners | Existing AABB face/corner handles + 2D handle ticks |
| Discoverable ops | `SelectionStrip` + RMB `PopupMenu` |
| View keys as buttons | `ViewHud` next to `ViewWidget` (W / K / Fit / Nav preset / Save view) |
| Fit selection | `OrbitCamera.frame_selection_or_all` (F); Shift+F / empty Fit all |
| RMB orbit vs menu | Press-drag orbit; soft click → context menu |
| Hover discoverability | Status line + pointing-hand cursor on hover change |
| Look at face | Strip / RMB → `look_along_model_normal` |

## Deferred (still peer-standard, not in this slice)

- Full marking menu / Onshape S-key toolbox
- Overlapping-pick disambiguation popup
- Sketch trim hover-cut preview
- Adaptive tool recommendation engine beyond selection menus
- Per-entity DOF coloring (solver reports whole-sketch DOF only)
- Constraint browser dock (glyphs are the visible surface for now)
- Instance rotation drag (translation only; rotation via mates)

## Related docs

- [master-feature-list.md](master-feature-list.md) — “Drag-handle editing”, direct face editing
- [howto/direct-edit.md](../howto/direct-edit.md) — end-user steps
- [howto/place-and-orbit.md](../howto/place-and-orbit.md) — place / camera
- [howto/edit-history.md](../howto/edit-history.md) — timeline rollback, constraint badges, dim editing
