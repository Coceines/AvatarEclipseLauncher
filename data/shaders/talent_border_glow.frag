// ============================================================
// TALENT BORDER GLOW SHADER
// Efeito de brilho elegante na borda dos talentos selecionados.
// Pulso suave + varredura dourada de brilho (sheen sweep).
// ============================================================
uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

const vec3 GOLD_COLOR    = vec3(1.00, 0.84, 0.38); // Dourado brilhante
const vec3 SHINE_COLOR   = vec3(1.00, 0.98, 0.85); // Brilho de luz quente
const vec3 AMBER_GLOW   = vec3(0.95, 0.65, 0.20); // Aura ambar

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Amostragem de vizinhos para aura externa suave (halo)
    vec2 step = vec2(1.8 / 52.0);
    float neighborA = 0.0;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2( step.x,  0.0)).a;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2(-step.x,  0.0)).a;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  step.y)).a;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -step.y)).a;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2( step.x,  step.y)).a * 0.7;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2(-step.x,  step.y)).a * 0.7;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2( step.x, -step.y)).a * 0.7;
    neighborA += texture2D(u_Tex0, v_TexCoord + vec2(-step.x, -step.y)).a * 0.7;
    neighborA /= 6.8;

    // Pulso suave de respiracao (ciclo de ~2.4s)
    float pulse = sin(u_Time * 2.6) * 0.18 + 0.92;

    // Varredura diagonal de brilho brilhante (sheen)
    float sweepWave = sin((v_TexCoord.x + v_TexCoord.y) * 3.8 - u_Time * 3.2);
    float sheen = pow(clamp(sweepWave, 0.0, 1.0), 5.0);

    // Pixel fora da textura principal mas dentro da aura
    if (texColor.a < 0.04) {
        if (neighborA > 0.02) {
            float haloAlpha = clamp((neighborA - texColor.a) * 0.75 * pulse, 0.0, 0.65);
            vec3 haloColor = mix(AMBER_GLOW, GOLD_COLOR, sheen * 0.5);
            gl_FragColor = vec4(haloColor * 1.2, haloAlpha);
            return;
        }
        discard;
    }

    // Pixel da borda
    vec3 rgb = texColor.rgb;

    // Intensifica o tom dourado com o pulso
    rgb = rgb * (pulse * 1.15) + (GOLD_COLOR * 0.18 * pulse);

    // Adiciona o brilho cintilante passando pela borda
    rgb += SHINE_COLOR * (sheen * 0.65);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), texColor.a);
}
