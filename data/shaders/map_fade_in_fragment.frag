varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;
uniform float u_Time;

// Recreate this shader before use so u_Time starts near 0.
const float FADE_SECONDS = 2.0;

void main()
{
    vec4 tex = texture2D(u_Tex0, v_TexCoord) * u_Color;
    float t = clamp(u_Time / FADE_SECONDS, 0.0, 1.0);
    // start black, reveal the map
    tex.rgb = mix(vec3(0.0), tex.rgb, t);
    if (t < 0.01) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    if (tex.a < 0.01)
        discard;
    gl_FragColor = tex;
}
