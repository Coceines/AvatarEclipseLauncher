// ============================================================
// HEALTHBAR BACKGROUND SHADER (Light, Subtle Sheen)
// ============================================================
uniform float u_Time;
uniform sampler2D u_Tex0;
uniform vec4 u_Color;
varying vec2 v_TexCoord;

void main()
{
    vec4 baseTex = texture2D(u_Tex0, v_TexCoord);
    if (baseTex.a < 0.05) {
        discard;
    }

    vec2 uv = v_TexCoord;

    float lum = dot(baseTex.rgb, vec3(0.299, 0.587, 0.114));
    float isBorder = clamp((lum - 0.16) / 0.18, 0.0, 1.0);

    float vCurve = 1.0 - abs(uv.y - 0.5) * 2.0;

    // Keep original image colors, just tint slightly
    float breath = sin(u_Time * 1.5) * 0.5 + 0.5;

    // Subtle sheen sweep
    float cycle = mod(u_Time, 4.5);
    float sweepActive = (cycle < 2.8) ? 1.0 : 0.0;
    float sweepPos = (cycle / 2.8) * 1.7 - 0.35;
    float dist = abs((uv.x + (uv.y - 0.5) * 0.35) - sweepPos);

    float sheenCore = exp(-dist * dist * 160.0);
    float sheenSoft = exp(-dist * dist * 28.0) * 0.30;
    float totalSheen = (sheenCore + sheenSoft) * sweepActive;
    vec3 sheenCol = vec3(0.78, 0.88, 1.00) * totalSheen * 0.25;

    // Border luster
    float borderFlow = sin(uv.x * 12.0 - u_Time * 1.6) * 0.5 + 0.5;
    float borderLum = isBorder * (0.15 + 0.10 * borderFlow + 0.06 * breath);
    vec3 borderLuster = vec3(0.78, 0.64, 0.42) * borderLum;

    // Gentle rim glow
    float topRim = smoothstep(0.04, 0.14, uv.y) * smoothstep(0.24, 0.14, uv.y);
    float botRim = smoothstep(0.96, 0.86, uv.y) * smoothstep(0.76, 0.86, uv.y);
    float rimGlow = (topRim + botRim) * (0.12 + 0.08 * breath);
    vec3 rimCol = vec3(0.10, 0.20, 0.38) * rimGlow;

    // Composite: keep original colors, add subtle effects
    vec3 finalRGB = baseTex.rgb + baseTex.rgb * 0.10 + borderLuster + rimCol + sheenCol;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), baseTex.a);
}
