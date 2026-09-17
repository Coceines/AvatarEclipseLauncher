/*
 * Sky Clouds Fragment Shader - v6
 *
 * All layers drift to the RIGHT at different speeds.
 * Speed matched to map_cloudy's u_Time scale.
 */

#define DEBUG_SKY 0

uniform sampler2D u_Tex0;
uniform float u_Time;

varying vec2 v_TexCoord;
varying vec2 v_WorldPos;

// ═══════════════════════════════════════════════════════════════════════════
//  Simplex-like noise
// ═══════════════════════════════════════════════════════════════════════════

vec3 permute(vec3 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }

float snoise(vec2 v)
{
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
            -0.577350269189626, 0.024390243902439);
    vec2 i = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod(i, 289.0);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// ═══════════════════════════════════════════════════════════════════════════
//  FBM cloud generation (4 octaves)
// ═══════════════════════════════════════════════════════════════════════════

float fbm(vec2 pos)
{
    float val = 0.0;
    float amp = 0.5;
    float scale = 1.0;
    for (int i = 0; i < 4; i++) {
        val += amp * (snoise(pos * scale) * 0.5 + 0.5);
        amp *= 0.5;
        scale *= 2.0;
    }
    return val;
}

float cloudShape(vec2 uv, float time)
{
    // All layers drift RIGHT only, at different parallax speeds.
    // Base speed matches map_cloudy: time * 0.15
    float drift = time * 0.15;

    vec2 c1 = uv * 0.15;
    c1.x += drift * 0.5;  // far: slowest

    vec2 c2 = uv * 0.4;
    c2.x += drift * 1.0;  // mid: medium

    vec2 c3 = uv * 0.8;
    c3.x += drift * 1.8;  // near: fastest

    float clouds = fbm(c1) * 0.5 + fbm(c2) * 0.35 + fbm(c3) * 0.15;

    return smoothstep(0.55, 0.75, clouds);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Sky detection - COLOR ONLY
// ═══════════════════════════════════════════════════════════════════════════

float skyMask(vec3 color)
{
    float r = color.r;
    float g = color.g;
    float b = color.b;

    float blueOverRed = b / (r + 0.001);
    float blueDominance = smoothstep(1.2, 1.8, blueOverRed);

    float blueIsLargest = smoothstep(0.0, 0.04, b - g);
    float greenOverRed = g / (r + 0.001);
    float greenIsMiddle = smoothstep(0.8, 1.1, greenOverRed);

    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float brightnessOk = smoothstep(0.12, 0.25, lum) * (1.0 - smoothstep(0.65, 0.85, lum));

    float mask = blueDominance * blueIsLargest * greenIsMiddle * brightnessOk;
    return clamp(mask, 0.0, 1.0);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════════════════

void main()
{
    vec4 mapColor = texture2D(u_Tex0, v_TexCoord);
    float mask = skyMask(mapColor.rgb);

    float time = u_Time;
    float clouds = cloudShape(v_WorldPos * 0.02, time) * 0.25;

    vec3 cloudColor = vec3(0.95, 0.97, 1.0);

#if DEBUG_SKY
    vec3 debugColor = mix(mapColor.rgb, vec3(0.0, 1.0, 0.0), mask * 0.5);
    gl_FragColor = vec4(debugColor, 1.0);
#else
    vec3 finalColor = mix(mapColor.rgb, cloudColor, clouds * mask);
    gl_FragColor = vec4(finalColor, 1.0);
#endif
}
