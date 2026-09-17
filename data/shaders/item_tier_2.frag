// Tier 2 Verde #4CAF50 - Soft Pulsing Outline (refined)
uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

const vec3 OUTLINE_COLOR = vec3(0.298, 0.686, 0.314);
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

    // Pulse mais vivo que o Tier 1
    float pulse = sin(u_Time * 3.4) * 0.28 + 0.72;

    // Glow um pouco mais presente
    float softGlow = smoothstep(0.0, 0.55, outline) * 0.48;

    // Leve brilho extra no pico do pulse
    float peak = max(0.0, sin(u_Time * 3.4));
    vec3 finalColor = OUTLINE_COLOR * (pulse + softGlow * 0.55) + OUTLINE_COLOR * peak * 0.12;

    vec4 outlineColor = vec4(finalColor, pulse * 0.98);

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha = smoothstep(0.0, 0.75, outlineAlpha);

    gl_FragColor = mix(texColor, outlineColor, outlineAlpha);

    if (gl_FragColor.a < 0.01)
        discard;
}