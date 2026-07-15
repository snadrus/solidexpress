# Stack three blocks

Goal: three default cubes (5 mm) sitting on top of each other (total height 15 mm).

## Steps

1. Click **Box** in the Palette, then click the **ground** to place the first block. It should sit on the grid.
2. Click **Box** again. Move the ghost over the **top face** of the first block (the face whose outward normal points up). Click that face. The new block’s floor sits on the previous top — status says *Stacked … on face*.
3. Repeat: **Box** → click the top of the second block. You now have three cubes: floors at `z = 0`, `5`, and `10`; overall top at `15`.
4. Middle-drag to orbit and confirm they are stacked, not overlapping in the same plane.

## Tips

- Clicking empty ground always places on `z = 0` (blocks will overlap each other in XY if you reuse the same spot).
- Dragging a body still slides it on the ground plane; use **place-on-face** to stack vertically.
- Esc cancels an armed placement before you click.

## What “good” looks like

- Three bodies in the timeline / document.
- Combined height ≈ 15 mm from the ground.

Verified by `run_howto_tests.gd` / `howto_stack_three_blocks`.
