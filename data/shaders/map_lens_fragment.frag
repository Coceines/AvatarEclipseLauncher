varying vec2 v_TexCoord;

uniform sampler2D u_Tex0;
uniform vec4 u_Color;
uniform vec2 u_Resolution;
uniform vec2 u_Center;
uniform vec2 u_Offset;

// 0.0 leaves the map untouched, higher values bend it harder.
// Must stay in sync with LENS_STRENGTH in modules/game_map_overlay/map_overlay.lua
// and with UIMinimap::lensAdjustPoint, which corrects mouse clicks for this distortion.
const float LENS_STRENGTH = 0.40;

// Subtle darkening towards the borders, like a real lens. 0.0 disables it.
const float EDGE_FALLOFF = 0.20;

void main()
{
    vec2 resolution = max(u_Resolution, vec2(1.0));
    vec2 halfSize = max(u_Offset, vec2(1.0));

    // Fragment position in pixels, measured from the center of the widget.
    vec2 q = v_TexCoord * resolution - u_Center;

    // Radius normalized by the CORNER radius: 0 on the center, exactly 1 on the
    // corners. The divisor has to be a single number. Measuring the radius
    // against the distance to the border (what this shader used to do) makes it
    // change from axis to axis: it is roughly 1 on the whole cross through the
    // center and ~1.4 on the diagonals, so the center came out small and the
    // sides stretched. A lens has to be round and isotropic.
    float maxRadius = max(length(halfSize), 1.0);
    float t = clamp(length(q) / maxRadius, 0.0, 1.0);

    // factor < 1 reads the source closer to the center and pushes that content
    // outwards, so the middle is magnified and the effect fades to nothing on
    // the corners; near the border the radial derivative turns it into real
    // compression, which is what makes the sides look small. The factor is
    // continuous at t = 0, so there is no singularity at the center.
    float factor = 1.0 - LENS_STRENGTH * (1.0 - t);

    vec2 source = u_Center + q * factor;
    vec2 uv = clamp(source / resolution, vec2(0.0), vec2(1.0));

    vec4 color = texture2D(u_Tex0, uv);
    color.rgb *= (1.0 - EDGE_FALLOFF * t * t) * u_Color.rgb;
    color.a *= u_Color.a;

    if (color.a < 0.004)
        discard;

    gl_FragColor = color;
}
