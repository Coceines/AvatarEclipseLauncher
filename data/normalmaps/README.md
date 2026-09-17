# Normal Map System for OTClient

## Overview

This system adds real 2D normal mapping to the OTClient renderer. Sprites with
associated normal maps react dynamically to light sources, creating a 2.5D
lighting effect while preserving the pixel-art style.

## How It Works

1. Each sprite can optionally have a tangent-space normal map
2. The normal map is a separate PNG with the same dimensions as the sprite
3. When rendering, the shader reads both the albedo (color) and the normal map
4. Light sources are applied per-pixel based on the surface normal
5. Sprites WITHOUT normal maps continue to work exactly as before

## Normal Map Convention

Normal maps use the standard tangent-space convention:
- **R** = X axis (left-right)
- **G** = Y axis (up-down)  
- **B** = Z axis (outward from surface)

A flat/neutral surface = RGB(128, 128, 255) = normal (0, 0, 1)

## File Naming Convention

Normal maps are stored in the `data/normalmaps/` directory:

```
data/normalmaps/
├── item/
│   ├── 1234_n.png      # Normal map for item clientId 1234
│   ├── 5678_n.png
│   └── ...
├── creature/
│   ├── 100_n.png       # Normal map for creature clientId 100
│   └── ...
├── effect/
│   └── ...
└── missile/
    └── ...
```

## Generating Normal Maps

Use the included Python tool to generate normal maps from existing sprites:

```bash
# Single image
python tools/generate_normalmap.py sprites/player.png normalmaps/creature/123_n.png

# Batch processing
python tools/generate_normalmap.py --batch sprites/ normalmaps/item/

# Adjust strength (default 2.0)
python tools/generate_normalmap.py --strength 3.0 input.png output_n.png
```

Requirements: `pip install Pillow`

## How to Add Normal Maps to Your Game

1. **Export sprites** from your .spr file using the OTClient export tool
2. **Generate normal maps** using the Python tool
3. **Place normal maps** in the appropriate `data/normalmaps/` subdirectory
4. **Restart the client** - normal mapping is detected automatically

If the `data/normalmaps/` directory doesn't exist, the system is disabled
automatically for zero performance impact.

## Technical Details

### Shader

The fragment shader (`glslNormalMapFragmentShader`) performs:
1. Reads albedo from the color texture (u_Tex0)
2. Reads and decodes the normal from the normal map (u_Tex1)
3. Computes diffuse lighting from up to 8 point lights + 1 directional sun
4. Applies smooth distance-based attenuation for point lights
5. Combines ambient + diffuse lighting with the albedo color

### Light Sources

- **Ambient Light**: Global minimum brightness from the map
- **Directional Sun**: Consistent light direction across all sprites
- **Point Lights**: From items/creatures with `hasLight()` attribute
- **Player Light**: The local player's light acts as a torch

### Performance

- Normal-mapped sprites bypass the atlas cache (they draw individually)
- Non-normal-mapped sprites continue to use the batched atlas path
- The system is disabled when no `data/normalmaps/` directory exists
- Normal map textures are cached per ThingType (not per animation phase)
- The shader runs efficiently on mobile GPUs (OpenGL ES 2.0 compatible)
