// ============================================================
// SPELLBAR BACKGROUND SHADER - AIR (Branco / Vento Etéreo)
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

    // Detect carved metallic border vs dark inner plate
    float lum = dot(baseTex.rgb, vec3(0.299, 0.587, 0.114));
    float isBorder = clamp((lum - 0.16) / 0.18, 0.0, 1.0);

    // Deep ethereal dark slate base
    float vCurve = 1.0 - abs(uv.y - 0.5) * 2.0;
    vec3 deepBase = vec3(0.048, 0.052, 0.062) + vec3(0.012, 0.015, 0.020) * vCurve;

    // Ethereal wind breathing pulse
    float breath = sin(u_Time * 1.5) * 0.5 + 0.5;

    // Diagonal pure diamond/silver sheen pass across the bar (4.5s cycle)
    float cycle = mod(u_Time, 4.5);
    float sweepActive = (cycle < 2.8) ? 1.0 : 0.0;
    float sweepPos = (cycle / 2.8) * 1.7 - 0.35;
    float dist = abs((uv.x + (uv.y - 0.5) * 0.35) - sweepPos);

    float sheenCore = exp(-dist * dist * 160.0);
    float sheenSoft = exp(-dist * dist * 28.0) * 0.30;
    float totalSheen = (sheenCore + sheenSoft) * sweepActive;
    vec3 sheenCol = vec3(1.00, 1.00, 1.00) * totalSheen * 0.45;

    // Luminous pure white/silver glow along carved border with wind flow
    float borderFlow = sin(uv.x * 12.0 - u_Time * 1.7) * 0.5 + 0.5;
    float borderLum = isBorder * (0.28 + 0.18 * borderFlow + 0.10 * breath);
    vec3 borderLuster = vec3(0.95, 0.98, 1.00) * borderLum;

    // White/silver inner rim underglow along the top and bottom ridges
    float topRim = smoothstep(0.04, 0.14, uv.y) * smoothstep(0.24, 0.14, uv.y);
    float botRim = smoothstep(0.96, 0.86, uv.y) * smoothstep(0.76, 0.86, uv.y);
    float rimGlow = (topRim + botRim) * (0.25 + 0.15 * breath);
    vec3 rimCol = vec3(0.48, 0.52, 0.58) * rimGlow;

    // Composite final color
    vec3 finalRGB = deepBase + baseTex.rgb * 0.30 + borderLuster + rimCol + sheenCol;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), baseTex.a * 0.96);
}
