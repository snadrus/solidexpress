# Extrude a custom S shape

Goal: sketch a closed S-shaped profile and extrude it into a solid.

## Steps

1. Click **Sketch** in the palette (or start a sketch on the ground plane). Status switches to sketch tools.
2. Press **L** (or click the Line tool) to draw. Turn snap off only if the solver fights you; for this outline, aim near these plane coordinates (mm):

   `(0,0) → (20,0) → (20,15) → (5,15) → (5,25) → (20,25) → (20,40) → (0,40) → (0,25) → (15,25) → (15,15) → (0,15) → (0,0)`

   That closed loop is a thick letter **S** (an S-channel). Click back near the start to close, or right-click to end the chain after the last segment lands on the start.
3. Press **Extrude** on the sketch toolbar (or finish with Enter if bound) with a distance such as **10**. Operation **New** creates a body.
4. Orbit (**Middle-drag**) to inspect the solid. It should be a single body with non-zero volume.

## Tips

- The profile must be **closed** or extrude fails — check that the last point meets the first.
- **R** draws rectangles; **C** circles; **S** returns to select for constraints.
- Esc cancels the sketch without creating a body.
- For a letter with a hole (outer + inner loop), see [extrude-letter-a.md](extrude-letter-a.md).

## What “good” looks like

- One body in the document after extrude.
- Mass / volume readout is clearly positive (thousands of mm³ for the outline above at 10 mm depth).

Verified by `run_howto_tests.gd` / `howto_extrude_s_shape`.
