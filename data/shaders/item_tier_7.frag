// ============================================================
// TIER 7 - DOURADO CLARO
// Soft Golden Sweep + Inner Glow + Elegant Outline
// ============================================================
//
// Efeito:
// - Faixa de luz dourada que atravessa a sprite
// - Glow interno suave e quente
// - Outline dourado elegante com pulse
// - Respeita completamente o alpha original
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
const vec3 GOLD       = vec3(1.000, 0.843, 0.000);
const vec3 BRIGHT     = vec3(1.000, 0.950, 0.550);
const vec3 WARM       = vec3(1.000, 0.780, 0.250);

// ============================================================
// MAIN
// ============================================================
void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // ========================================================
    // 1) COORDENADA DIAGONAL (mesma ideia do Tier 10)
    // ========================================================
    float diag = v_TexCoord.x * 0.70 + v_TexCoord.y * 0.30;

    // ========================================================
    // 2) SWEEP DOURADO
    // ========================================================
    float cycle   = fract(u_Time * 0.28);
    float beamPos = mix(-0.20, 1.20, cycle);

    float dist = abs(diag - beamPos);

    // Faixa principal
    float glassWidth = 0.13;
    float glass = 1.0 - smoothstep(glassWidth, glassWidth + 0.09, dist);

    // Brilho central mais fino
    float centerShine = 1.0 - smoothstep(0.0, 0.028, dist);
    centerShine *= 0.75;

    // Intensidade final do sweep
    float sweepIntensity = clamp(glass * 0.55 + centerShine, 0.0, 1.0);

    // ========================================================
    // 3) GLOW INTERNO (fica o tempo todo)
    // ========================================================
    float innerPulse = sin(u_Time * 2.4) * 0.06 + 0.16;
    float innerGlow  = texColor.a * innerPulse;

    // ========================================================
    // 4) APLICAÇÃO DOS EFEITOS POR CIMA DO ITEM
    // ========================================================
    vec3 finalRGB = texColor.rgb;

    // Glow quente permanente
    finalRGB += WARM * innerGlow;

    // Sweep dourado passando
    vec3 sweepColor = mix(GOLD, BRIGHT, 0.55);
    finalRGB = mix(finalRGB, sweepColor, sweepIntensity * 0.58 * texColor.a);

    // Highlight branco bem sutil no centro da faixa
    finalRGB += vec3(1.0) * centerShine * 0.18 * texColor.a;

    finalRGB = clamp(finalRGB, 0.0, 1.0);

    vec4 withEffects = vec4(finalRGB, texColor.a);

    // ========================================================
    // 5) OUTLINE DOURADO
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

    // Pulse suave da outline
    float pulse = sin(u_Time * 2.8) * 0.14 + 0.86;
    vec3 outlineColor = mix(GOLD, BRIGHT, 0.35) * pulse;

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha *= 0.88;

    // ========================================================
    // 6) COMPOSIÇÃO FINAL
    // ========================================================
    vec4 finalColor = mix(withEffects, vec4(outlineColor, 1.0), outlineAlpha);

    // Garante que o alpha original nunca é destruído
    finalColor.a = max(texColor.a, outlineAlpha);

    if (finalColor.a < 0.01)
        discard;

    gl_FragColor = finalColor;
}