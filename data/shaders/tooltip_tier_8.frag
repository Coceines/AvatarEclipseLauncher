// ============================================================
// TOOLTIP TIER 8 - CYAN #00D9F2 (Clean Rounded Borders + Godrays)
// ============================================================
uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

const vec3 TIER_COLOR = vec3(0.04, 0.86, 0.96);

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

    vec2 boxHalfSize = vec2(0.485, 0.485);
    float cornerRadius = 0.045;
    float dist = roundedBoxSDF(p, boxHalfSize, cornerRadius);

    float alpha = smoothstep(0.003, -0.002, dist);
    if (alpha <= 0.001) {
        discard;
    }

    vec3 baseDark = vec3(0.065, 0.082, 0.125);
    float angle = atan(p.y, p.x);

    float borderLine = smoothstep(-0.018, -0.003, dist) * smoothstep(0.002, -0.003, dist);
    float edgeDepth = clamp(-dist / 0.16, 0.0, 1.0);
    float innerGlow = pow(1.0 - edgeDepth, 2.5);

    float ray1 = sin(angle * 12.0 + u_Time * 1.5) * 0.5 + 0.5;
    float ray2 = cos(angle * 18.0 - u_Time * 1.2) * 0.5 + 0.5;
    float rays = pow(ray1 * 0.55 + ray2 * 0.45, 2.8);
    float godrayFade = pow(1.0 - edgeDepth, 2.0) * smoothstep(1.0, 0.05, edgeDepth);
    float godrays = rays * godrayFade * 0.42;

    float pulse = sin(u_Time * 2.7) * 0.12 + 0.88;
    float sheen = pow(sin(angle * 3.0 + u_Time * 2.1) * 0.5 + 0.5, 4.0) * borderLine;

    vec3 glow = TIER_COLOR * (borderLine * 1.30 + innerGlow * 0.35 + godrays * 0.70 + sheen * 0.60) * pulse;
    vec3 finalRGB = baseDark + glow;
    finalRGB += vec3(0.3, 0.5, 0.6) * sheen * pulse;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), alpha * 0.96);
}
