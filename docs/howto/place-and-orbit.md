# Place a box and orbit the camera

Goal: drop one solid that sits on the ground plane, keep it selected, and orbit — including on a touchpad with no middle button.

## Steps

1. In the left **Palette**, click **Box** (do not drag). The status bar says *Click ground or a face to place box*. A translucent ghost appears with its **floor** on the ground grid.
2. Move the pointer — the ghost should follow. Click anywhere on the ground plane (the XY grid). The solid appears under the ghost.
3. The new box stays **selected** (highlighted). The Modify / timeline panels may open; that is expected.
4. Orbit with any of:
   - **Alt + left-drag** (best on a touchpad)
   - **Two-finger drag** on a trackpad (pan gesture)
   - **Middle-drag** on a mouse
   - **Shift** held with any of the above → pan instead of orbit
   - **Wheel** or **pinch** → zoom toward the cursor
   - **F** frames all bodies; **1 / 2 / 3 / 7** jump to front / right / top / isometric
5. To cancel a place before committing, press **Esc** (or right-click).

## What “good” looks like

- The ghost tracks the pointer after you arm place (not stuck at screen center).
- The box sits on the ground (`z = 0` floor, top at 50 for the default 50 mm cube).
- After the place click, the box remains selected.
- Alt-drag orbits even when side panels are open.

Verified by `run_howto_tests.gd` / `howto_place_and_orbit`.
