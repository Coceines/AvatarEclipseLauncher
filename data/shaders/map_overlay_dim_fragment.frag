varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;
uniform float u_Time;

void main()
{
    vec4 tex = texture2D(u_Tex0, v_TexCoord);

    vec2 d = v_TexCoord - vec2(0.5, 0.5);
    float dist = clamp(length(d) * 1.41421356, 0.0, 1.0);

    float alpha = mix(0.72, 0.78, dist);

    gl_FragColor = vec4(0.0, 0.0, 0.0, alpha * tex.a);
}
