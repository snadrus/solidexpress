# Direct edit: hover, select, pull, move

Goal: place a box, see what a click will hit, then reshape and move it with on-canvas handles — without opening the Modify dock.

## Steps

1. Place a **Box** from the palette (see [place-and-orbit.md](place-and-orbit.md)).
2. Move the pointer over the solid **without clicking**. The body / face under the cursor brightens (hover). The status bar names **Body / Face / Edge**. Selected objects use a stronger tint plus corner brackets.
3. Click the body to select it. You should see:
   - Blue AABB / corner brackets
   - RGB **rotate arcs** (grab a tick on the ring to rotate about that axis)
   - Blue **stretch arrows** (single outward chevron on each face — primitives)
   - A yellow **lift** grip (double-headed elevator inset into the solid along the active-plane normal — leave / approach the plane; mid plate stays clear of the blue +Z stretch)
   - A thin **Fillet / Sketch / Look at / Active plane / Hide / Delete** strip at the top (Sketch / Look at / Active plane appear when a face is selected; **Join / Subtract / Intersect** appear for multi-body selection and apply instantly)
4. **Drag the solid itself** (after a short move past the click slop) to move it on the **active plane** (default: world XY). Tiny clicks still refine selection instead of nudging. While dragging you see the **old** and **new** center marks, an editable **Δ** row, and the **Snap to grid** bar (same checkbox + resolution as place). Magnets also pull to nearby bodies: selection **center** or **AABB face mid** → their center or face mid (nearest body, or the body under the pointer if you pass over one). Each magnet only holds within a few screen pixels of a perfect match and draws a dotted snap guide with the gap between the closest surfaces. Drag the yellow **lift** grip (or tap **Z** mid-drag) for motion along the plane normal; tap **X** / **Y** to lock planar axes.
   - **Set the active plane:** select a flat face → strip **Active plane** or RMB **Set as active plane**; or **View → Set Active Plane…** and click a face (empty ground resets to world XY). The white reference grid moves onto that plane; a dashed yellow quad also hints when a custom plane is active.
5. Click a face again to select the face. An orange **Pull** arrow appears. Drag the arrow — a live mm badge shows the distance; release commits. Use **Look at** (strip or RMB) for a SolidWorks-style normal-to view.
6. **Right-click** for a context menu. **Right-drag** orbits instead (menu only on click without drag).
7. **Space** opens an orientation panel (Front / Right / Top / Iso / Fit / Ortho / restore “User”). ViewHud **Save view** stores “User”.
8. Use **Shade / Section / Fit** and **Nav: SX / SW / Fusion** in the top-right ViewHud. SX/Fusion: middle-drag (3-finger grip on a trackpad) pans; choose **Nav: SW** for SolidWorks-style middle-orbit. Snap views with **Space** or **1 / 2 / 3 / 7**.
9. **Component instances** (Assembly panel → Place instance) are draggable too: click one to select it (slim strip with Delete), drag to move it on the ground plane. If it is mated, releasing the drag re-solves the mates and the instance snaps back into position — the SolidWorks “drag it, constraints pull it home” feel.

## What “good” looks like

- Hover color is clearly different from selection color; status advertises Body / Face / Edge.
- Rotate arcs and stretch grips are obvious; the body mesh is the move grip.
- Orbit (empty / right / Alt / two-finger) does not clear selection unless you truly click empty space.
- Push/pull shows a distance badge while dragging.
- Context strip and RMB stay in sync with the current selection.

Verified by `run_visual_ux_tests.gd` / `run_move_snap_tests.gd` / `run_camera_tests.gd` / `run_assembly_tests.gd`.
