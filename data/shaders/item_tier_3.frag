// Tier 3 Azul #2196F3 - Soft Pulsing Outline (refined)
uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

const vec3 OUTLINE_COLOR = vec3(0.129, 0.588, 0.953);
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

    // Pulse mais forte e com mais presença
    float pulse = sin(u_Time * 3.8) * 0.32 + 0.70;

    // Glow mais destacado
    float softGlow = smoothstep(0.0, 0.48, outline) * 0.58;

    // Pico de brilho + leve tom mais claro no peak
    float peak = max(0.0, sin(u_Time * 3.8));
    vec3 brightBlue = mix(OUTLINE_COLOR, vec3(0.35, 0.72, 1.0), 0.35); // leve cyan no pico

    vec3 finalColor = OUTLINE_COLOR * (pulse + softGlow * 0.65) + brightBlue * peak * 0.18;

    vec4 outlineColor = vec4(finalColor, pulse * 1.0);

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha = smoothstep(0.0, 0.68, outlineAlpha);

    gl_FragColor = mix(texColor, outlineColor, outlineAlpha);

    if (gl_FragColor.a < 0.01)
        discard;
}