# Crank-slider joint

Goal: a crank and slider share **connectors**. The slider X is the analytic `a·cosθ + √(b² − a²sin²θ)` position — not a guessed drag.

## Steps

1. Place a box (stand-in crank body).
2. **Mode → Model** stays; joints consume the same connectors as Fastened.
3. `crank_slider_x(20, 80, 0)` = 100 mm. At 90° the slider is `√(80² − 20²)`.

## What “good” looks like

- θ = 0 → x = 100 mm.
- θ = 90° → x ≈ 77.5 mm.

Film: `crank_slider`. Kernel: `[wave1][joints]`.
