// ============================================================
// TIER 8 - CRYSTAL CYAN
// Crystal Sweep + Cold Glow + Sharp Outline
// ============================================================
//
// Efeito:
// - Faixa de luz ciano/cristal que atravessa a sprite
// - Glow frio interno
// - Outline ciano nítido com pulse
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
const vec3 CYAN       = vec3(0.000, 0.850, 0.950);
const vec3 BRIGHT     = vec3(0.550, 0.980, 1.000);
const vec3 COLD       = vec3(0.200, 0.650, 0.900);

// ============================================================
// MAIN
// ============================================================
void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // ========================================================
    // 1) COORDENADA DIAGONAL
    // ========================================================
    float diag = v_TexCoord.x * 0.65 + v_TexCoord.y * 0.35;

    // ========================================================
    // 2) CRYSTAL SWEEP
    // ========================================================
    float cycle   = fract(u_Time * 0.34);
    float beamPos = mix(-0.22, 1.22, cycle);

    float dist = abs(diag - beamPos);

    // Faixa principal (um pouco mais fina e nítida)
    float glassWidth = 0.11;
    float glass = 1.0 - smoothstep(glassWidth, glassWidth + 0.075, dist);

    // Brilho central bem cortante
    float centerShine = 1.0 - smoothstep(0.0, 0.022, dist);
    centerShine *= 0.80;

    // Linhas secundárias (efeito cristal)
    float side1 = 1.0 - smoothstep(0.0, 0.015, abs(dist - 0.048));
    float side2 = 1.0 - smoothstep(0.0, 0.015, abs(dist + 0.048));
    float sides = (side1 + side2) * 0.28;

    float sweepIntensity = clamp(glass * 0.50 + centerShine + sides, 0.0, 1.0);

    // ========================================================
    // 3) GLOW FRIO INTERNO
    // ========================================================
    float innerPulse = sin(u_Time * 2.9) * 0.05 + 0.14;
    float innerGlow  = texColor.a * innerPulse;

    // ========================================================
    // 4) APLICAÇÃO DOS EFEITOS
    // ========================================================
    vec3 finalRGB = texColor.rgb;

    // Glow frio
    finalRGB += COLD * innerGlow;

    // Sweep cristalino
    vec3 sweepColor = mix(CYAN, BRIGHT, 0.60);
    finalRGB = mix(finalRGB, sweepColor, sweepIntensity * 0.62 * texColor.a);

    // Highlight branco no centro
    finalRGB += vec3(1.0) * centerShine * 0.20 * texColor.a;

    finalRGB = clamp(finalRGB, 0.0, 1.0);

    vec4 withEffects = vec4(finalRGB, texColor.a);

    // ========================================================
    // 5) OUTLINE CIANO
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

    float pulse = sin(u_Time * 3.3) * 0.15 + 0.85;
    vec3 outlineColor = mix(CYAN, BRIGHT, 0.40) * pulse;

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha *= 0.90;

    // ========================================================
    // 6) COMPOSIÇÃO FINAL
    // ========================================================
    vec4 finalColor = mix(withEffects, vec4(outlineColor, 1.0), outlineAlpha);

    finalColor.a = max(texColor.a, outlineAlpha);

    if (finalColor.a < 0.01)
        discard;

    gl_FragColor = finalColor;
}