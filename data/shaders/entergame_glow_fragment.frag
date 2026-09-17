// ============================================================
// ENTERGAME GLOW - brilho bem suave nas bordas da arte do login
//
// Alvo: logo.png, a imagem da janela enterGame (EnterGameWindow,
// modules/client_entergame/entergame.otui). A janela e' 380x480 e a arte e'
// esticada para preencher ela inteira, entao a borda do desenho e' a borda da
// janela.
//
// Como funciona: o shader DESENHA A PROPRIA ARTE (amostra u_Tex0 e devolve
// igual) e soma luz nas bordas - maxima na borda da imagem, desaparecendo em
// GLOW_PX pixels para dentro. Fora dessa faixa o pixel sai exatamente como veio
// da arte, ou seja, o miolo da janela nao muda em nada. Como o alpha continua
// sendo o da arte, pixel transparente continua transparente: nao aparece
// moldura nenhuma.
//
// O halo e' medido em pixels de tela (por isso WIDGET, o tamanho logico da
// janela). Esses 380x480 sao fixos: o EnterGame.setUniqueServer() aplica
// exatamente esses valores em tempo de execucao. Se a janela mudar de tamanho,
// e' so' acompanhar WIDGET aqui.
//
// u_Color e' obrigatorio aqui: e' por ele que o motor aplica a image-color do
// widget e a OPACIDADE (o fade do UIWindow faz setOpacity(0 -> 1) no show, e o
// DrawQueue multiplica isso no m_color de cada item). Sem multiplicar por ele a
// arte apareceria de uma vez, sem acompanhar o fade do resto da janela.
//
// Ajustes (bem leve mesmo):
//   GLOW_PX    - espessura do brilho, em pixels (30 = faixa de 3% a 30px)
//   GLOW_MAX   - intensidade maxima, na propria borda (0.10 = 10%)
//   GLOW_COLOR - cor da luz (dourado quente, combina com a moldura)
// ============================================================
uniform sampler2D u_Tex0;
uniform vec4 u_Color;
varying vec2 v_TexCoord;

const vec2  WIDGET     = vec2(380.0, 480.0);
const float GLOW_PX    = 30.0;
const float GLOW_MAX   = 0.10;
const vec3  GLOW_COLOR = vec3(1.00, 0.88, 0.66);

void main()
{
    vec2 uv = clamp(v_TexCoord, 0.0, 1.0);
    vec4 texColor = texture2D(u_Tex0, uv);

    // distancia, em pixels, ate' a borda mais proxima da janela
    float dist = min(min(uv.x, 1.0 - uv.x) * WIDGET.x,
                     min(uv.y, 1.0 - uv.y) * WIDGET.y);

    // 1 na borda, 0 em GLOW_PX; ao quadrado sobra so' um veu fino
    float glow = 1.0 - smoothstep(0.0, GLOW_PX, dist);
    glow *= glow;

    // (arte + brilho) * image-color/opacidade do widget, igual ao caminho
    // normal do motor quando o widget nao tem shader
    vec3 rgb = clamp((texColor.rgb + GLOW_COLOR * (glow * GLOW_MAX)) * u_Color.rgb, 0.0, 1.0);
    gl_FragColor = vec4(rgb, texColor.a * u_Color.a);
}
