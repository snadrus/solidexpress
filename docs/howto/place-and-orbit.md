# Place a box and orbit the camera

Goal: drop one solid that sits on the ground plane, keep it selected, and orbit — including on a touchpad with no middle button.

## Steps

1. The empty scene starts zoomed in on a **0.1 mm** ground grid (1 mm majors). In the left **Primitives** palette, click **Box** (do not drag). The status bar says *Click ground or a face to place box*. A translucent ghost appears with its **floor** on the ground grid. A bottom bar shows editable **X/Y/Z** (place point) and **W×H×D** size, plus **Snap to grid** (default on, 0.1 mm).
2. Move the pointer — the ghost should follow (snapped if snap is on). Optionally type a precise size in the bottom bar before placing. Click anywhere on the ground plane (the XY grid). The solid appears under the ghost.
3. The new box stays **selected** (highlighted with a blue AABB / corner brackets). The left rail swaps: **Primitives** hides and **Modify** tools take that space. Position and size stay editable in the bottom HUD.
4. Orbit with any of:
   - **Two-finger drag** on a trackpad (pan gesture) — hold a click while two-finger dragging for a stronger turn; over a scrollbar panel, two-finger scroll moves the panel instead
   - **Empty-space drag** (left-drag where nothing is picked)
   - **Right-drag** (right-**click** alone opens the context menu)
   - **Alt + left-drag** (best on a touchpad if two-finger is awkward)
   - **Middle-drag** on a mouse — SX/SW: orbit; set **Nav: Fusion** in the view HUD to pan with middle
   - **Shift** held with middle / Alt-left → pan (or orbit under the Fusion preset)
   - **Double-middle** → fit selection (or all)
   - **Wheel** or **pinch** → zoom toward the cursor (same UI rule as two-finger scroll)
   - **Ctrl + empty-drag** → rubber-band box select
   - **Shift + click** → add / toggle multi-select (Shift+empty keeps selection)
   - **Empty click** → clear selection
   - **F** frames the **selection** (or all if none); **Shift+F** always frames all; **Space** opens the orientation panel; **1 / 2 / 3 / 7** jump to front / right / top / isometric
5. Drag on the solid to **move** it on the horizontal plane (old/new centers + editable Δ appear; tap **X**/**Y**/**Z** mid-drag to lock that axis — a highlighted axis line shows the lock; **Z** freezes XY and pairs with typed **ΔZ** for vertical-only moves). Grab a stretch tick/corner or a colored **rotate arc** just outside the silhouette to stretch/rotate. On release, refine the focused **Δ** / **Δ°** field and press Enter.
6. To cancel a place before committing, press **Esc** (or right-click without dragging). Click empty space to deselect and bring **Primitives** back.

## What “good” looks like

- The ghost tracks the pointer after you arm place (not stuck at screen center).
- Snap-to-grid + position/size HUD are visible while place is armed.
- The box sits on the ground (`z = 0` floor, top at 10 for the default 10 mm cube).
- After the place click, the box remains selected with clear corner brackets; left chrome shows Modify tools, not Primitives.
- Empty-space drag and Alt-drag orbit even when side panels are open.
- Scrolling a dock with a scrollbar does not zoom the 3D view.

Verified by `run_howto_tests.gd` / `howto_place_and_orbit`.

Next: reshape and move with on-canvas handles — [direct-edit.md](direct-edit.md).
