// ============================================================
// TIER 9 - ARCANE MAGENTA
// Horizontal Energy Sweep + Core Pulse + Soft Outline
// ============================================================
//
// Efeito:
// - Faixa de energia HORIZONTAL (não diagonal)
// - Pulso forte no centro do item
// - Glow magenta interno
// - Outline magenta com pulse mais vivo
// - Respeita o alpha original
//
// ============================================================
uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

// ============================================================
// CONFIG
// ============================================================
const float THICKNESS = 2.0;
const vec3 MAGENTA    = vec3(0.95, 0.20, 0.65);
const vec3 BRIGHT     = vec3(1.00, 0.55, 0.90);
const vec3 DEEP       = vec3(0.55, 0.05, 0.40);

// ============================================================
// MAIN
// ============================================================
void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // ========================================================
    // 1) COORDENADA HORIZONTAL (diferente dos tiers anteriores)
    // ========================================================
    float horiz = v_TexCoord.y; // varre de cima pra baixo

    // ========================================================
    // 2) ENERGY SWEEP HORIZONTAL
    // ========================================================
    float cycle   = fract(u_Time * 0.31);
    float beamPos = mix(-0.18, 1.18, cycle);

    float dist = abs(horiz - beamPos);

    // Faixa principal
    float width = 0.12;
    float beam = 1.0 - smoothstep(width, width + 0.08, dist);

    // Núcleo bem brilhante
    float core = 1.0 - smoothstep(0.0, 0.025, dist);
    core *= 0.85;

    // Bordas suaves da faixa
    float edge1 = 1.0 - smoothstep(0.0, 0.016, abs(dist - 0.045));
    float edge2 = 1.0 - smoothstep(0.0, 0.016, abs(dist + 0.045));
    float edges = (edge1 + edge2) * 0.25;

    float sweepIntensity = clamp(beam * 0.52 + core + edges, 0.0, 1.0);

    // ========================================================
    // 3) CORE PULSE (brilho que nasce do centro do item)
    // ========================================================
    vec2 center = v_TexCoord - vec2(0.5);
    float distCenter = length(center);

    float corePulse = sin(u_Time * 3.6) * 0.5 + 0.5;
    corePulse = pow(corePulse, 1.8);

    float radial = 1.0 - smoothstep(0.15, 0.55, distCenter);
    float centerGlow = radial * corePulse * 0.28 * texColor.a;

    // ========================================================
    // 4) GLOW INTERNO FIXO
    // ========================================================
    float innerGlow = texColor.a * (0.13 + sin(u_Time * 2.2) * 0.04);

    // ========================================================
    // 5) APLICAÇÃO DOS EFEITOS
    // ========================================================
    vec3 finalRGB = texColor.rgb;

    // Glow profundo
    finalRGB += DEEP * innerGlow;

    // Pulso do centro
    finalRGB += BRIGHT * centerGlow;

    // Sweep horizontal
    vec3 sweepColor = mix(MAGENTA, BRIGHT, 0.55);
    finalRGB = mix(finalRGB, sweepColor, sweepIntensity * 0.60 * texColor.a);

    // Highlight branco no núcleo da faixa
    finalRGB += vec3(1.0) * core * 0.18 * texColor.a;

    finalRGB = clamp(finalRGB, 0.0, 1.0);

    vec4 withEffects = vec4(finalRGB, texColor.a);

    // ========================================================
    // 6) OUTLINE MAGENTA
    // ========================================================
    vec2 px = (THICKNESS / 512.0) * vec2(1.0);
    vec2 hs = px * 0.5;

    float a = 0.0;

    // Inner
    a += texture2D(u_Tex0, v_TexCoord + vec2(-hs.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( hs.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -hs.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  hs.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-hs.x, -hs.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( hs.x, -hs.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-hs.x,  hs.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( hs.x,  hs.y)).a;

    // Outer
    a += texture2D(u_Tex0, v_TexCoord + vec2(-px.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( px.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -px.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  px.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-px.x, -px.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( px.x, -px.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-px.x,  px.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( px.x,  px.y)).a;

    float outline = min(a, 1.0);

    float pulse = sin(u_Time * 3.8) * 0.16 + 0.84;
    vec3 outlineColor = mix(MAGENTA, BRIGHT, 0.35) * pulse;

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha *= 0.90;

    // ========================================================
    // 7) COMPOSIÇÃO FINAL
    // ========================================================
    vec4 finalColor = mix(withEffects, vec4(outlineColor, 1.0), outlineAlpha);

    finalColor.a = max(texColor.a, outlineAlpha);

    if (finalColor.a < 0.01)
        discard;

    gl_FragColor = finalColor;
}