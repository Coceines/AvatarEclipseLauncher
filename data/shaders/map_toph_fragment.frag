// ============================================================
//  TOPH MODE  (menu FUN -> Toph Mode)  --  mapa
//
//  O que ele faz:
//    1. escurece TUDO que esta' no mapa para 5% (95% escuro);
//    2. preserva e faz brilhar os pixels pintados com a cor EXATA #9bd2fb
//       (o outfit_toph pinta o contorno de criaturas/players com ela) e
//       acende um halo suave em volta deles  ->  o "glow simples";
//    3. solta uma onda senoidal circular em volta do personagem
//       (centro da camera) a cada 5 segundos.
//
//  Contrato com outfit_toph_fragment: KEY e' a ponte entre os dois shaders.
//  Nao mude a cor aqui sem mudar la' (e o tophmode.lua usa a mesma constante
//  para a cor do nome/mensagem).
// ============================================================

varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform vec4 u_Color;
uniform float u_Time;
uniform vec2 u_Resolution;
uniform vec2 u_Center;

const float DARK  = 0.05;                                   // 95% escuro
const vec3  KEY   = vec3(155.0 / 255.0, 210.0 / 255.0, 251.0 / 255.0); // #9bd2fb
const float TILE  = 32.0;                                   // 1 SQM em pixels
const float WAVE_SECONDS = 5.0;                             // 1 onda a cada 5s

// quao perto a cor esta' da cor do contorno
float keyness(vec3 c)
{
    return 1.0 - smoothstep(0.0, 0.035, distance(c, KEY));
}

void main()
{
    vec4 tex = texture2D(u_Tex0, v_TexCoord) * u_Color;
    if (tex.a < 0.01)
        discard;

    vec3 col = tex.rgb * DARK;

    // ------------------------------------------------------------------
    // 1) criaturas / players: o contorno pintado com KEY fica aceso
    // ------------------------------------------------------------------
    float k = keyness(tex.rgb) * step(0.5, tex.a);

    // halo simples: procura KEY em 2 aneis de 8 direcoes (16 amostras)
    vec2 onePixel = vec2(1.0) / max(u_Resolution, vec2(1.0));
    float halo = 0.0;
    for (int ring = 1; ring <= 2; ++ring) {
        float r = float(ring) * 2.5;
        float found = 0.0;
        for (int i = 0; i < 8; ++i) {
            float a = float(i) * 0.7853982;                 // 45 graus
            vec2 off = vec2(cos(a), sin(a)) * r * onePixel;
            found = max(found, keyness(texture2D(u_Tex0, v_TexCoord + off).rgb));
        }
        halo = max(halo, found * (1.0 - float(ring) * 0.35));
    }
    halo *= (1.0 - k);
    col = mix(col, KEY, halo * 0.5);

    // ------------------------------------------------------------------
    // 2) onda senoidal circular em volta do personagem (a cada 5s)
    // ------------------------------------------------------------------
    vec2  p     = v_TexCoord * u_Resolution - u_Center + vec2(32.0, 32.0);
    float dist  = length(p) / TILE;                         // distancia em SQMs
    float phase = fract(u_Time / WAVE_SECONDS);             // 0..1 a cada 5s
    float radius = 0.6 + phase * 5.4;                       // expande 0.6 -> 6 SQMs
    float width  = 0.35 + phase * 0.9;                      // engorda enquanto anda
    float ring   = 1.0 - smoothstep(0.0, width, abs(dist - radius));
    float sine   = 0.55 + 0.45 * sin(dist * 6.2831853 - u_Time * 3.0);
    float wave   = ring * sine * pow(1.0 - phase, 1.6) * 0.55;

    col = mix(col, KEY, k);                                 // o contorno, cheio
    col += KEY * wave;

    gl_FragColor = vec4(col, tex.a);
}
