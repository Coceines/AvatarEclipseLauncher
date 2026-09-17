// Tier 5 Laranja/Dourado #FF9800 - Soft Pulsing Outline + Shine
uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

const vec3 OUTLINE_COLOR = vec3(1.000, 0.596, 0.000);
const float THICKNESS = 2.0;

void main()
{
    vec2 step = (THICKNESS / 512.0) * vec2(1.0);
    vec2 halfStep = step * 0.5;

    // Multi-ring sampling
    float a = 0.0;

    // Inner ring
    a += texture2D(u_Tex0, v_TexCoord + vec2(-halfStep.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( halfStep.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -halfStep.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  halfStep.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-halfStep.x, -halfStep.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( halfStep.x, -halfStep.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-halfStep.x,  halfStep.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( halfStep.x,  halfStep.y)).a;

    // Outer ring
    a += texture2D(u_Tex0, v_TexCoord + vec2(-step.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( step.x,  0.0)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -step.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  step.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-step.x, -step.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( step.x, -step.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2(-step.x,  step.y)).a;
    a += texture2D(u_Tex0, v_TexCoord + vec2( step.x,  step.y)).a;

    float outline = min(a, 1.0);
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Pulse principal mais forte
    float pulse = sin(u_Time * 4.5) * 0.38 + 0.68;

    // Pulse secundário mais lento (dá profundidade)
    float pulse2 = sin(u_Time * 2.1) * 0.15 + 0.85;

    // Glow bem presente
    float softGlow = smoothstep(0.0, 0.38, outline) * 0.82;

    // ===== Frufru 1: Brilho viajante (shine que corre pela outline) =====
    float angle = atan(v_TexCoord.y - 0.5, v_TexCoord.x - 0.5);
    float shine = sin(angle * 4.0 + u_Time * 6.5) * 0.5 + 0.5;
    shine = pow(shine, 3.5); // deixa o brilho mais concentrado e elegante

    // ===== Frufru 2: Cor que muda de laranja → dourado nos picos =====
    float peak = max(0.0, sin(u_Time * 4.5));
    vec3 goldColor = mix(OUTLINE_COLOR, vec3(1.0, 0.85, 0.35), 0.55);

    vec3 finalColor = OUTLINE_COLOR * (pulse * pulse2 + softGlow * 0.85);
    finalColor += goldColor * peak * 0.32;
    finalColor += goldColor * shine * 0.45; // brilho viajante

    vec4 outlineColor = vec4(finalColor, min(pulse * 1.08, 1.0));

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha = smoothstep(0.0, 0.52, outlineAlpha);

    gl_FragColor = mix(texColor, outlineColor, outlineAlpha);

    if (gl_FragColor.a < 0.01)
        discard;
}