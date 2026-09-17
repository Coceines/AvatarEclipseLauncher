// ============================================================
// BACKGROUND PARTICLES - particulas subindo: AZUL na metade esquerda da tela,
// VERMELHA na metade direita. Elas nascem na base, sobem e somem chegando na
// linha horizontal do meio da tela.
//
// Onde esta' aplicado: painel "particles" de
// modules/client_background/background.otui - um painel do tamanho da tela,
// filho do painel de fundo (por isso fica atras da janela de login e na frente
// da imagem de fundo).
//
// Este shader NAO desenha a imagem de fundo: ele devolve so' as particulas, com
// alpha, entao o que estiver atras (a imagem de fundo) continua aparecendo. A
// textura do widget nao entra na conta - ela existe apenas porque o motor exige
// uma imagem para aplicar o shader.
//
// As medidas usam u_Resolution (tamanho da tela em pixels), entao o efeito fica
// igual em qualquer resolucao ou tamanho de janela.
//
// Ajustes:
//   COUNT     - total de particulas (metade de cada cor)
//   MID_Y     - linha horizontal onde elas somem (0.5 = meio da tela)
//   SPEED     - velocidade da subida, em fracao da tela por segundo
//   SIZE_PX   - tamanho do brilho de cada uma, em pixels
//   INTENSITY - brilho/opacidade maxima somada na tela
//   BLUE/RED  - cores das duas metades
// ============================================================
uniform float u_Time;
uniform vec2 u_Resolution;
uniform vec4 u_Color;
varying vec2 v_TexCoord;

const int   COUNT     = 48;
const float MID_Y     = 0.50;
const float BOTTOM_Y  = 1.02;
const float SPEED     = 0.075;
const float SIZE_PX   = 6.0;
const float SWAY      = 0.012;
const float INTENSITY = 0.85;
const vec3  BLUE      = vec3(0.32, 0.62, 1.00);
const vec3  RED       = vec3(1.00, 0.28, 0.26);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
    vec2 uv = v_TexCoord;
    vec2 res = max(u_Resolution, vec2(1.0));

    vec3 color = vec3(0.0);
    float alpha = 0.0;

    for (int i = 0; i < COUNT; i++) {
        float id = float(i);

        // par (0) sobe na metade esquerda, azul; impar (1) na direita, vermelha
        float side = mod(id, 2.0);

        // cada uma com sua fase e um pouco de velocidade propria
        float phase = hash(vec2(id, 1.1));
        float speed = SPEED * (0.55 + 0.9 * hash(vec2(id, 2.2)));
        float t = fract(phase + u_Time * speed);

        // x nasce dentro da propria metade; o balanco nunca cruza o meio
        float xin = mix(0.03, 0.46, hash(vec2(id, 3.3)));
        float x = mix(xin, 1.0 - xin, side);
        x += sin(u_Time * 0.55 + id * 1.7) * SWAY;
        x = mix(clamp(x, 0.015, 0.485), clamp(x, 0.515, 0.985), side);

        // t = 0 nasce na base, t = 1 chega no meio da tela
        float y = mix(BOTTOM_Y, MID_Y, t);

        // distancia em pixels: o brilho continua redondo em qualquer resolucao
        float d = length((uv - vec2(x, y)) * res);
        float glow = (SIZE_PX * SIZE_PX) / (d * d + SIZE_PX * SIZE_PX);
        glow *= glow;

        // nasce suave na base e some chegando no meio da tela
        glow *= smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.60, 1.0, t));

        // cintila
        glow *= 0.62 + 0.38 * sin(u_Time * 2.3 + id * 7.7);

        // nucleo levemente mais claro que a cor da metade
        vec3 tint = mix(mix(BLUE, RED, side), vec3(1.0), 0.18 * glow);
        color += tint * glow;
        alpha += glow;
    }

    color = clamp(color * INTENSITY, 0.0, 1.0) * u_Color.rgb;
    alpha = clamp(alpha * INTENSITY, 0.0, 1.0) * u_Color.a;
    gl_FragColor = vec4(color, alpha);
}
