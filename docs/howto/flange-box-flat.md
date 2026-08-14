# Flange box — flat length

Goal: a flange is sheet metal. Unfold it; flat length uses K-factor bend allowance.

## Steps

1. **Mode → Sheet** (split folded | flat, bend-table strip).
2. Add a flange (length 30, T 1.5, K 0.44, R 1.5).
3. Flat = L1 + L2 + BA − 2T.

## What “good” looks like

- `flat_length` on the feature > 30 mm.
- Same document — not a second file.

Film: `flange_box_flat`. Kernel: `[wave2][sheet]`.
