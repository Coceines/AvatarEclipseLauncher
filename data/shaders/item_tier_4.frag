// Tier 4 Roxo #9C27B0 - Soft Pulsing Outline (refined)
uniform mat4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

const vec3 OUTLINE_COLOR = vec3(0.612, 0.153, 0.690);
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

    // Pulse mais forte e com ritmo um pouco mais acelerado
    float pulse = sin(u_Time * 4.2) * 0.36 + 0.68;

    // Glow bem mais presente
    float softGlow = smoothstep(0.0, 0.42, outline) * 0.70;

    // Pico com tom magenta / rosa para dar mais vida
    float peak = max(0.0, sin(u_Time * 4.2));
    vec3 brightPurple = mix(OUTLINE_COLOR, vec3(0.85, 0.35, 1.0), 0.40);

    vec3 finalColor = OUTLINE_COLOR * (pulse + softGlow * 0.75) + brightPurple * peak * 0.25;

    vec4 outlineColor = vec4(finalColor, min(pulse * 1.05, 1.0));

    float outlineAlpha = clamp(outline - texColor.a, 0.0, 1.0);
    outlineAlpha = smoothstep(0.0, 0.60, outlineAlpha);

    gl_FragColor = mix(texColor, outlineColor, outlineAlpha);

    if (gl_FragColor.a < 0.01)
        discard;
}