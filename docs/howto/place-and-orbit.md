# Place a box and orbit the camera

Goal: drop one solid that sits on the ground plane, keep it selected, and orbit with the middle mouse button even when the side panels are open.

## Steps

1. In the left **Palette**, click **Box** (do not drag). The status bar says *Click ground or a face to place box*. A translucent ghost appears with its **floor** on the ground grid.
2. Move the mouse — the ghost follows. Click anywhere on the ground plane (the XY grid). The solid appears under the ghost; the status bar confirms the insert and reminds you that middle-drag orbits.
3. The new box stays **selected** (highlighted). The Modify / timeline panels may open; that is expected.
4. **Middle-drag** in the viewport (or even over the right-hand panels) to orbit. **Shift+Middle-drag** pans; the mouse **wheel** zooms toward the cursor. Press **F** to frame all bodies; **1 / 2 / 3 / 7** jump to front / right / top / isometric.
5. To cancel a place before committing, press **Esc** (or right-click).

## What “good” looks like

- The box sits on the ground (`z = 0` floor, top at 50 for the default 50 mm cube), not hovering or half-buried.
- After the place click, the box remains selected (you can open Fillet / Chamfer on it).
- Orbit still works after panels appear.

Verified by `run_howto_tests.gd` / `howto_place_and_orbit`.
