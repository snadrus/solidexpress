# Visual sketch tools (SolidWorks-class, planar)

Goal: use the compact left rail and on-canvas chips to draw, modify, and constrain sketches without a free 3D sketch mode.

## Left rail (primaries)

In sketch mode the left rail shows: **Exit Sketch**, Select, Line, Arc, Circle, Rect, Polygon, Ellipse, Slot, Spline, Point, Trim, Extend, Smart Dim, Convert, Mirror, Pattern — plus Snap / Infer and DOF readout.

Variants and numeric options appear **on-canvas** (floating chips), not as permanent rail spinboxes.

## On-canvas chips

1. Arm **Rect / Circle / Arc / Pattern** — a variant strip appears (corner/center/3-pt; center/perimeter; center/tangent/3-pt; linear/circular).
2. Select one or more entities — action chips: Construction, Delete, Fillet, Chamfer, Offset, Pattern, Mirror, Block, Split, and common relations.
3. Finish strip (top-left while sketching): Dim value, Extrude distance/op, Extrude / Revolve.

## Power Trim

- Tool **Trim** (T): hover highlights the nearest segment in red; click trims it.
- Drag across entities to cut each one the cursor crosses (SW-like Power Trim).

## Derived geometry

- **Convert**: turns pierce / plane-intersection points into sketch points.
- **Mirror**: select geometry plus one axis line, then Mirror.
- **Pattern**: linear (kernel) or circular (rotated copies) via variant chips.
- **Smart Dim** (D): click a line for length, circle/arc for radius, or two points for distance.

## Blocks & picture

- Selection → **Block** names the current selection for reuse; `place_block` offsets a copy.
- `set_sketch_picture(texture)` draws a translucent underlay on the plane for tracing.

## 3D paths without 3D sketch

See [multi-sketch-merge.md](multi-sketch-merge.md): Ctrl+click yellow pads → Merge sketches… → Path feature → Sweep along path.
