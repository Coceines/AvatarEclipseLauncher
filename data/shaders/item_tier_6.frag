// Tier 6 Vermelho #F44336 - Aggressive Pulsing Outline + Dual Shine
uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

const vec3 OUTLINE_COLOR = vec3(0.957, 0.263, 0.212);
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

    // Pulse principal bem mais agressivo
    float pulse = sin(u_Time * 5.2) * 0.42 + 0.68;

    // Pulse secundário + terciário (dá sensação de fogo vivo)
    float pulse2 = sin(u_Time * 2.7) * 0.18 + 0.82;
    float flicker = sin(u_Time * 11.0) * 0.08 + 0.92; // flicker rápido

    // Glow forte
    float softGlow = smoothstep(0.0, 0.32, outline) * 0.95;

    // ===== Dual Shine (dois brilhos correndo em direções opostas) =====
    float angle = atan(v_TexCoord.y - 0.5, v_TexCoord.x - 0.5);
    float shine1 = sin(angle * 5.0 + u_Time * 7.5) * 0.5 + 0.5;
    float shine2 = sin(angle * 3.0 - u_Time * 5.8) * 0.5 + 0.5;
    shine1 = pow(shine1, 4.0);
    shine2 = pow(shine2, 5.5);

    // ===== Cor quente: Vermelho → Laranja → Quase branco nos picos =====
    float peak = max(0.0, sin(u_Time * 5.2));
    vec3 hotOrange = mix(OUTLINE_COLOR, vec3(1.0, 0.45, 0.15), 0.55);
    vec3 hotWhite  = mix(hotOrange, vec3(1.0, 0.85, 0.7), 0.45);

    vec3 finalColor = OUTLINE_COLOR * (pulse * pulse2 * flicker + softGlow * 0.9);
    finalColor += hotOrange * peak * 0.38;
    finalColor += hotWhite  * (shine1 * 0.55 + shine2 * 0.35);

    vec4 outlineColor = vec4(finalColor, min(pulse * 1.12, 1.0));

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha = smoothstep(0.0, 0.45, outlineAlpha);

    gl_FragColor = mix(texColor, outlineColor, outlineAlpha);

    if (gl_FragColor.a < 0.01)
        discard;
}