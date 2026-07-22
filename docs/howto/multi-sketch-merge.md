# Multi-sketch merge (3D path substitute)

SolidExpress has no free 3D sketch environment. Build sweep/loft paths by merging planar sketches.

## Steps

1. Create **Sketch A** on one plane (e.g. ground) with an open line path; Exit Sketch.
2. Create **Sketch B** on a second plane (e.g. a vertical face) with another open segment; Exit Sketch.
3. **Ctrl+click** (or Cmd+click) each yellow sketch pad until two or more are selected. Status reports the count.
4. On-canvas chips appear:
   - **Merge join** — nearest-neighbor polyline through line endpoints (`join_endpoints`)
   - **Merge spline** — Catmull densify through those points (`bridge_spline`)
   - **Merge composite** — same chain packing (`composite`)
   - **Merge clear** — drop the pad selection
5. A **Path** feature is added to the timeline (no solid). It stores sketch refs and regenerates `path` points when those sketches change.
6. Create a closed profile sketch, then sweep with `graph_add_sweep_along_path(profile_fid, path_fid)` (or voice/script). Edit source planar sketches to update the path associatively.

## What “good” looks like

- No freeform 3D doodling — edit planar sources.
- Path appears in the timeline as type `path`.
- Sweep along that path produces a solid; regenerating after editing a source sketch updates the path polyline.

Verified by kernel `[featsweep][path]` and Godot sketch-parity tests.
