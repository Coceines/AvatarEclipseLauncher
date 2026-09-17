// ============================================================
// TIER 10 - ANCESTRAL
// VITRAL + GLASS SHINE + RGB OUTLINE
// ============================================================
//
// Efeito:
// - Reflexo de vidro/vitral atravessa a sprite inteira
// - Faixa diagonal contínua
// - Gradiente RGB dentro do reflexo
// - Pequenos highlights brancos
// - Outline RGB animado
// - Respeita alpha original da sprite
//
// ============================================================

uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;


// ============================================================
// CONFIGURAÇÕES
// ============================================================

const float THICKNESS = 2.0;


// ============================================================
// HUE RGB
// ============================================================

vec3 hue2rgb(float h)
{
    h = fract(h);

    float r = abs(h * 6.0 - 3.0) - 1.0;
    float g = 2.0 - abs(h * 6.0 - 2.0);
    float b = 2.0 - abs(h * 6.0 - 4.0);

    return clamp(vec3(r, g, b), 0.0, 1.0);
}


// ============================================================
// MAIN
// ============================================================

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // ========================================================
    // 1) COORDENADA DIAGONAL
    // ========================================================
    //
    // A faixa atravessa a sprite inteira.
    //
    // Usamos X + Y para criar uma diagonal.
    //

    float diag = v_TexCoord.x * 0.72 +
                 v_TexCoord.y * 0.28;


    // ========================================================
    // 2) MOVIMENTO DO VITRAL
    // ========================================================
    //
    // O ciclo possui uma pequena pausa fora da sprite,
    // mas quando entra, atravessa completamente de ponta
    // a ponta.
    //
    // O movimento real vai de -0.25 até 1.25.
    //

    float cycle = fract(u_Time * 0.22);

    float beamPos = mix(-0.25, 1.25, cycle);


    // ========================================================
    // 3) DISTÂNCIA DA FAIXA
    // ========================================================

    float dist = abs(diag - beamPos);


    // ========================================================
    // 4) CORPO PRINCIPAL DO VITRAL
    // ========================================================
    //
    // Faixa relativamente larga.
    //

    float glassWidth = 0.16;

    float glass = 1.0 - smoothstep(
        glassWidth,
        glassWidth + 0.10,
        dist
    );


    // ========================================================
    // 5) GRADIENTE MULTICOLORIDO
    // ========================================================
    //
    // Em vez de simplesmente deixar a faixa branca,
    // criamos várias cores dentro dela.
    //

    float glassHue =
        diag * 2.8
        - u_Time * 0.08;


    vec3 glassRGB = hue2rgb(glassHue);


    // ========================================================
    // 6) SEGUNDO GRADIENTE DE COR
    // ========================================================
    //
    // Mistura outra tonalidade para criar aparência de vitral.
    //

    vec3 glassRGB2 =
        hue2rgb(glassHue + 0.18);


    glassRGB =
        mix(
            glassRGB,
            glassRGB2,
            smoothstep(
                -glassWidth,
                glassWidth,
                diag - beamPos
            )
        );


    // ========================================================
    // 7) VIDRO BRANCO
    // ========================================================
    //
    // Mantemos bastante branco para parecer reflexo de vidro,
    // mas sem apagar a cor original.
    //

    vec3 glassColor =
        mix(
            vec3(1.0),
            glassRGB,
            0.48
        );


    // ========================================================
    // 8) BRILHO CENTRAL
    // ========================================================
    //
    // Uma linha branca estreita atravessa o centro do reflexo.
    //

    float centerShine =
        1.0 -
        smoothstep(
            0.0,
            0.035,
            dist
        );


    centerShine *= 0.85;


    // ========================================================
    // 9) BRILHO SECUNDÁRIO
    // ========================================================
    //
    // Duas linhas menores acompanham a faixa principal.
    //

    float secondary1 =
        1.0 -
        smoothstep(
            0.0,
            0.018,
            abs(dist - 0.055)
        );


    float secondary2 =
        1.0 -
        smoothstep(
            0.0,
            0.018,
            abs(dist + 0.055)
        );


    float secondary =
        (secondary1 + secondary2) * 0.30;


    // ========================================================
    // 10) INTENSIDADE FINAL DO VITRAL
    // ========================================================

    float glassIntensity =
        glass * 0.65 +
        centerShine +
        secondary;


    glassIntensity =
        clamp(
            glassIntensity,
            0.0,
            1.0
        );


    // ========================================================
    // 11) APLICAÇÃO DO VITRAL
    // ========================================================
    //
    // Muito importante:
    // o efeito só altera RGB.
    // O alpha original continua intacto.
    //

    vec3 finalRGB =
        mix(
            texColor.rgb,
            glassColor,
            glassIntensity * 0.65
        );


    // ========================================================
    // 12) HIGHLIGHT BRANCO
    // ========================================================

    finalRGB +=
        vec3(1.0) *
        centerShine *
        0.22;


    finalRGB =
        clamp(
            finalRGB,
            0.0,
            1.0
        );


    vec4 withGlass =
        vec4(
            finalRGB,
            texColor.a
        );


    // ========================================================
    // 13) RGB OUTLINE
    // ========================================================

    vec2 step2 =
        (THICKNESS / 512.0) *
        vec2(1.0, 1.0);

    vec2 hs =
        step2 * 0.5;


    float a = 0.0;


    // --------------------------------------------------------
    // Primeira camada
    // --------------------------------------------------------

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(-hs.x,  0.0)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( hs.x,  0.0)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( 0.0, -hs.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( 0.0,  hs.y)
    ).a;


    // --------------------------------------------------------
    // Diagonais
    // --------------------------------------------------------

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(-hs.x, -hs.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( hs.x, -hs.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(-hs.x,  hs.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( hs.x,  hs.y)
    ).a;


    // --------------------------------------------------------
    // Segunda distância
    // --------------------------------------------------------

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(-step2.x, 0.0)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( step2.x, 0.0)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(0.0, -step2.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(0.0,  step2.y)
    ).a;


    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(-step2.x, -step2.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( step2.x, -step2.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2(-step2.x,  step2.y)
    ).a;

    a += texture2D(
        u_Tex0,
        v_TexCoord + vec2( step2.x,  step2.y)
    ).a;


    float outline =
        min(a, 1.0);


    // ========================================================
    // 14) RGB ANIMADO
    // ========================================================

    float outlineHue =
        fract(
            u_Time * 0.18 +
            diag * 0.35
        );


    vec3 outlineRGB =
        hue2rgb(outlineHue);


    // ========================================================
    // 15) PULSAÇÃO SUAVE
    // ========================================================

    float pulse =
        sin(u_Time * 2.5) *
        0.12 +
        0.88;


    outlineRGB *= pulse;


    // ========================================================
    // 16) ALPHA DO OUTLINE
    // ========================================================

    float outlineAlpha =
        clamp(
            outline - texColor.a,
            0.0,
            1.0
        );


    // Deixa o outline mais elegante
    outlineAlpha *= 0.85;


    // ========================================================
    // 17) COMPOSIÇÃO
    // ========================================================

    vec4 finalColor =
        mix(
            withGlass,
            vec4(
                outlineRGB,
                1.0
            ),
            outlineAlpha
        );


    // ========================================================
    // 18) GARANTIR ALPHA ORIGINAL
    // ========================================================

    //
    // Isso evita que o shader crie um "quadrado"
    // em volta da sprite.
    //

    finalColor.a =
        max(
            texColor.a,
            outlineAlpha
        );


    // ========================================================
    // 19) DESCARTE
    // ========================================================

    if (finalColor.a < 0.01)
        discard;


    gl_FragColor =
        finalColor;
}