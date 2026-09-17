// ============================================================
// TOOLTIP TIER 10 - ANCESTRAL RAINBOW (Clean Rounded Borders + Godrays)
// ============================================================
uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

vec3 hue2rgb(float h)
{
    h = fract(h);
    float r = abs(h * 6.0 - 3.0) - 1.0;
    float g = 2.0 - abs(h * 6.0 - 2.0);
    float b = 2.0 - abs(h * 6.0 - 4.0);
    return clamp(vec3(r, g, b), 0.0, 1.0);
}

float roundedBoxSDF(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main()
{
    vec2 uv = v_TexCoord;
    vec2 center = vec2(0.5, 0.5);
    vec2 p = uv - center;

    // Rounded rectangle SDF (clean rounded corners)
    vec2 boxHalfSize = vec2(0.485, 0.485);
    float cornerRadius = 0.045;
    float dist = roundedBoxSDF(p, boxHalfSize, cornerRadius);

    // Antialiased outer edge clip
    float alpha = smoothstep(0.003, -0.002, dist);
    if (alpha <= 0.001) {
        discard;
    }

    // Clean, elegant dark background for pristine text legibility
    vec3 baseDark = vec3(0.065, 0.082, 0.125);

    // Spectrum rainbow hue flowing smoothly along the perimeter
    float angle = atan(p.y, p.x);
    float rainbowHue = fract(angle * 0.159 + (uv.x + uv.y) * 0.25 + u_Time * 0.18);
    vec3 tierColor = hue2rgb(rainbowHue);

    // Crisp outer glowing border line (2px feel)
    float borderLine = smoothstep(-0.018, -0.003, dist) * smoothstep(0.002, -0.003, dist);

    // Soft inward atmospheric glow near edges
    float edgeDepth = clamp(-dist / 0.16, 0.0, 1.0);
    float innerGlow = pow(1.0 - edgeDepth, 2.5);

    // Godrays: subtle light shafts projecting inward from edges towards center
    float ray1 = sin(angle * 12.0 + u_Time * 1.4) * 0.5 + 0.5;
    float ray2 = cos(angle * 18.0 - u_Time * 1.1) * 0.5 + 0.5;
    float ray3 = sin(angle * 6.0 + u_Time * 0.7) * 0.5 + 0.5;
    float rays = pow(ray1 * 0.45 + ray2 * 0.35 + ray3 * 0.20, 2.8);

    // Godrays fade smoothly inward so the center remains totally clean and readable
    float godrayFade = pow(1.0 - edgeDepth, 2.0) * smoothstep(1.0, 0.05, edgeDepth);
    float godrays = rays * godrayFade * 0.45;

    // Gentle vitality breathing pulse
    float pulse = sin(u_Time * 2.5) * 0.12 + 0.88;

    // Moving sheen traveling around the border
    float sheen = pow(sin(angle * 3.0 + u_Time * 2.0) * 0.5 + 0.5, 4.0) * borderLine;

    // Combine lighting
    vec3 glow = tierColor * (borderLine * 1.3 + innerGlow * 0.35 + godrays * 0.70 + sheen * 0.6) * pulse;

    // Very subtle center ambient warmth so it feels alive but 100% dark & clean
    vec3 finalRGB = baseDark + glow;

    // Crisp white specular highlight along peak of the border sheen
    finalRGB += vec3(0.5, 0.5, 0.6) * sheen * pulse;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), alpha * 0.96);
}
