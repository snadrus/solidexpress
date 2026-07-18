# Synthetic Grand Canyon HDRI pack for Godot 4

This package is derived from the approved generated 360-degree panorama. It contains **synthetically expanded HDR radiance**, not measured photographic HDR data. The visible sun has been assigned strong radiance so it can produce crisp highlights in metallic and glossy materials.

## Recommended use
Copy this whole folder into your project as `res://canyon_hdri/`.

- Use `resources/CanyonLightingWorldEnvironment.tscn` for balanced image-based lighting.
- Use `resources/CanyonReflectionWorldEnvironment.tscn` when the environment is primarily visible through polished materials.
- Open `demo/CanyonHDRIDemo.tscn` to inspect chrome, brushed-metal, and glossy surfaces.

## Included maps
- `textures/canyon_lighting_4k.hdr`: 4096x2048 RGBE panorama with a high-radiance sun and balanced canyon/sky bounce.
- `textures/canyon_reflection_4k.hdr`: 4096x2048 RGBE panorama with increased landmark contrast, saturation, and texture detail.
- Seam-fixed PNG and tone-mapped JPG previews.
- Six 1024x1024 HDR cubemap faces for each variant, plus PNG previews.

## Godot import notes
Godot normally recognizes `.hdr` as linear floating-point content. Do not treat it as sRGB. Keep filtering enabled. For sharp reflections, the supplied Sky resources use `radiance_size = 5` (2048). Reduce this if import time or VRAM use is too high.

The equirectangular HDR panorama is the normal Godot `PanoramaSkyMaterial` input. The cubemap faces are supplied for external pipelines and custom shaders; the stock Godot sky resources do not need them.

## Important limitation
No algorithm can recover physically measured highlight information from an SDR generated image. This pack creates deliberate synthetic radiance and useful reflection detail. It should look substantially better on PBR objects than the SDR panorama, but it is not suitable where calibrated photometric lighting is required.
