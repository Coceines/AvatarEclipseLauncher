// ============================================================
// SPELLBAR BACKGROUND SHADER (Clean, Subtle, Elegant Sheen & Glow)
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

    // Subtle vertical curve for rich ambient depth
    float vCurve = 1.0 - abs(uv.y - 0.5) * 2.0;
    vec3 deepBase = vec3(0.045, 0.058, 0.095) + vec3(0.015, 0.020, 0.035) * vCurve;

    // Calm breathing pulse
    float breath = sin(u_Time * 1.5) * 0.5 + 0.5;

    // Sleek diagonal specular gleam (sheen wave across the bar)
    // 4.5s total cycle: sweeps smoothly across in 2.8s, then rests for 1.7s
    float cycle = mod(u_Time, 4.5);
    float sweepActive = (cycle < 2.8) ? 1.0 : 0.0;
    float sweepPos = (cycle / 2.8) * 1.7 - 0.35;
    float dist = abs((uv.x + (uv.y - 0.5) * 0.35) - sweepPos);

    float sheenCore = exp(-dist * dist * 160.0);
    float sheenSoft = exp(-dist * dist * 28.0) * 0.30;
    float totalSheen = (sheenCore + sheenSoft) * sweepActive;
    vec3 sheenCol = vec3(0.78, 0.88, 1.00) * totalSheen * 0.40;

    // Golden / bronze luster along the carved border details
    float borderFlow = sin(uv.x * 12.0 - u_Time * 1.6) * 0.5 + 0.5;
    float borderLum = isBorder * (0.22 + 0.14 * borderFlow + 0.08 * breath);
    vec3 borderLuster = vec3(0.78, 0.64, 0.42) * borderLum;

    // Gentle inner rim underglow along the top and bottom ridges
    float topRim = smoothstep(0.04, 0.14, uv.y) * smoothstep(0.24, 0.14, uv.y);
    float botRim = smoothstep(0.96, 0.86, uv.y) * smoothstep(0.76, 0.86, uv.y);
    float rimGlow = (topRim + botRim) * (0.22 + 0.12 * breath);
    vec3 rimCol = vec3(0.10, 0.20, 0.38) * rimGlow;

    // Composite final color
    vec3 finalRGB = deepBase + baseTex.rgb * 0.35 + borderLuster + rimCol + sheenCol;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), baseTex.a * 0.95);
}
