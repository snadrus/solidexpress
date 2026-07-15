# Direct edit: hover, select, pull, move

Goal: place a box, see what a click will hit, then reshape and move it with on-canvas handles — without opening the Modify dock.

## Steps

1. Place a **Box** from the palette (see [place-and-orbit.md](place-and-orbit.md)).
2. Move the pointer over the solid **without clicking**. The body / face under the cursor brightens (hover). The status bar names **Body / Face / Edge**. Selected objects use a stronger tint plus corner brackets.
3. Click the body to select it. You should see:
   - Blue AABB / corner brackets
   - RGB **rotate arcs** (grab a tick on the ring to rotate about that axis)
   - Blue **stretch** face ticks and corner diamonds (primitives) — grab just outside the silhouette
   - A thin **Fillet / Sketch / Look at / Hide / Delete** strip at the top (Sketch / Look at appear when a face is selected)
4. **Drag the solid itself** (after a short move past the click slop) to move it on the horizontal plane. Tiny clicks still refine selection instead of nudging. While dragging you see the **old** and **new** center marks plus an editable **Δ** row. Tap **X** or **Y** mid-drag to lock the move to that axis (tap again to free). Type **ΔZ** to hop off-plane.
5. Click a face again to select the face. An orange **Pull** arrow appears. Drag the arrow — a live mm badge shows the distance; release commits. Use **Look at** (strip or RMB) for a SolidWorks-style normal-to view.
6. **Right-click** for a context menu. **Right-drag** orbits instead (menu only on click without drag).
7. **Space** opens an orientation panel (Front / Right / Top / Iso / Fit / Ortho / restore “User”). ViewHud **Save view** stores “User”.
8. Use **Shade / Section / Fit** and **Nav: SX / SW / Fusion** beside the ViewCube. Fusion users: choose **Nav: Fusion** so middle-drag pans.
9. **Component instances** (Assembly panel → Place instance) are draggable too: click one to select it (slim strip with Delete), drag to move it on the ground plane. If it is mated, releasing the drag re-solves the mates and the instance snaps back into position — the SolidWorks “drag it, constraints pull it home” feel.

## What “good” looks like

- Hover color is clearly different from selection color; status advertises Body / Face / Edge.
- Rotate arcs and stretch grips are obvious; the body mesh is the move grip.
- Orbit (empty / right / Alt / two-finger) does not clear selection unless you truly click empty space.
- Push/pull shows a distance badge while dragging.
- Context strip and RMB stay in sync with the current selection.

Verified by `run_visual_ux_tests.gd` / `run_camera_tests.gd` / `run_assembly_tests.gd`.
