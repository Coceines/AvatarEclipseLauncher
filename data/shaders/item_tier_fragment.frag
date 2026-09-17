uniform vec4 u_Color;
varying vec2 v_TexCoord;
uniform sampler2D u_Tex0;
uniform float u_Time;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);

    // Skip fully transparent pixels
    if (texColor.a < 0.01)
        discard;

    // u_Color.rgb = glow color, u_Color.a = intensity
    vec3 glowColor = u_Color.rgb;
    float intensity = u_Color.a;

    // Pulsing effect
    float pulse = 0.75 + 0.25 * sin(u_Time * 4.0);

    // Edge detection via alpha gradient
    vec2 texelSize = vec2(1.0 / 32.0);
    float aN = texture2D(u_Tex0, v_TexCoord + vec2(0.0, texelSize.y)).a;
    float aS = texture2D(u_Tex0, v_TexCoord - vec2(0.0, texelSize.y)).a;
    float aE = texture2D(u_Tex0, v_TexCoord + vec2(texelSize.x, 0.0)).a;
    float aW = texture2D(u_Tex0, v_TexCoord - vec2(texelSize.x, 0.0)).a;

    float edgeFactor = 0.0;
    if (texColor.a > 0.5) {
        float minNeighbor = min(min(aN, aS), min(aE, aW));
        edgeFactor = 1.0 - minNeighbor;
    }

    vec3 result = texColor.rgb;

    // Inner glow: subtle tint on the whole item
    float innerGlow = intensity * 0.3 * pulse;
    result = mix(result, glowColor, innerGlow);

    // Edge glow: brighter on edges
    float edgeGlow = edgeFactor * intensity * 0.7 * pulse;
    result = mix(result, glowColor, edgeGlow);

    // Overall brightness boost
    result += glowColor * intensity * 0.15 * pulse;

    gl_FragColor = vec4(result, texColor.a);
}
