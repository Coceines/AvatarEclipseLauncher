// ============================================================
//  TOPH MODE  --  outfit (criaturas e players)
//
//  Desenha o sprite normalmente e pinta a BEIRADA com a cor EXATA #9bd2fb.
//  Nao escurece nada aqui: quem escurece e' o map_toph, que reconhece essa
//  cor exata e deixa o contorno aceso no meio do escuro (com halo).
//  -> Nao mude KEY sem mudar map_toph_fragment.frag.
// ============================================================

varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform vec4 u_Color;

const vec3 KEY  = vec3(155.0 / 255.0, 210.0 / 255.0, 251.0 / 255.0); // #9bd2fb
const vec2 STEP = vec2(1.6 / 512.0, 1.6 / 512.0);                    // espessura do contorno

void main()
{
    vec4 base = texture2D(u_Tex0, v_TexCoord) * u_Color;

    // 8 vizinhos (mesma tecnica dos outros shaders de contorno do client)
    float around = 0.0;
    around += texture2D(u_Tex0, v_TexCoord + vec2(-STEP.x,  0.0)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  STEP.y)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2( STEP.x,  0.0)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -STEP.y)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2(-STEP.x,  STEP.y)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2( STEP.x,  STEP.y)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2(-STEP.x, -STEP.y)).a;
    around += texture2D(u_Tex0, v_TexCoord + vec2( STEP.x, -STEP.y)).a;
    around = min(around, 1.0);

    // beirada = vizinho tem desenho e este pixel nao tem
    float rim = clamp(around - base.a, 0.0, 1.0);

    if (base.a < 0.05) {
        // fora do sprite: o contorno em si (cor exata, para o map_toph achar)
        if (rim < 0.02)
            discard;
        gl_FragColor = vec4(KEY, 1.0);
        return;
    }

    // dentro do sprite: leve lavagem azulada na beirada (glow simples)
    gl_FragColor = vec4(mix(base.rgb, KEY, rim * 0.8), base.a);
}
