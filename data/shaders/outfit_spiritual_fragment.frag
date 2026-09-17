uniform mat4 u_Color;
varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;
uniform sampler2D u_Tex0;
uniform float u_Time;

void main()
{
    gl_FragColor = texture2D(u_Tex0, v_TexCoord);
    vec4 texcolor = texture2D(u_Tex0, v_TexCoord2);
    if (texcolor.r > 0.9)
        gl_FragColor *= texcolor.g > 0.9 ? u_Color[0] : u_Color[1];
    else if (texcolor.g > 0.9)
        gl_FragColor *= u_Color[2];
    else if (texcolor.b > 0.9)
        gl_FragColor *= u_Color[3];

    // Ghostly blue spiritual tint + soft pulse
    float pulse = 0.85 + 0.15 * sin(u_Time * 3.0);
    vec3 spirit = vec3(0.45, 0.70, 1.0);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, spirit, 0.55) * pulse;
    gl_FragColor.a *= 0.72;

    if (gl_FragColor.a < 0.01)
        discard;
}
