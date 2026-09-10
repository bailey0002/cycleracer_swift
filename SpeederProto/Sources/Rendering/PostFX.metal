#include <metal_stdlib>
using namespace metal;

// Must match PostUniforms in PostProcessor.swift (six float4s).
struct PostUniforms {
    float4 vanishingTexel;  // x,y: vanishing point (uv)  z,w: unused
    float4 bloom;           // x: bloom intensity  y: streak intensity  z: streak length  w: fog density
    float4 fogColor;        // rgb: fog colour  w: horizon glow boost
    float4 proj;            // x: P[2][2]  y: P[3][2]  z: exposure  w: vignette
    float4 misc;            // x: chromatic aberration  y: time  z: saturation  w: grade strength
    float4 flags;           // x: fog  y: bloom  z: streaks  w: grade   (0/1); flags.x < 0 => passthrough
};

static inline float luminance(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

static inline float3 aces(float3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

// Pass 1: threshold bright pixels into a quarter-resolution buffer.
kernel void brightPass(texture2d<float, access::sample> src [[texture(0)]],
                       texture2d<float, access::write> dst [[texture(1)]],
                       constant PostUniforms &u [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    // 4-tap box for stability on thin neon lines
    float2 px = 0.5 / float2(src.get_width(), src.get_height());
    float3 c = src.sample(s, uv + float2(-px.x, -px.y)).rgb
             + src.sample(s, uv + float2( px.x, -px.y)).rgb
             + src.sample(s, uv + float2(-px.x,  px.y)).rgb
             + src.sample(s, uv + float2( px.x,  px.y)).rgb;
    c *= 0.25;
    float l = luminance(c);
    float threshold = u.vanishingTexel.w > 0.0 ? u.vanishingTexel.w : 0.74;
    float knee = 0.25;
    float soft = clamp(l - threshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee + 1e-4);
    float contribution = max(soft, l - threshold) / max(l, 1e-4);
    dst.write(float4(c * contribution, 1.0), gid);
}

// Diagnostic: copy a few depth samples into a tiny readable texture so the CPU can
// verify the depth buffer is actually readable on this GPU/simulator.
kernel void depthProbe(texture2d<float, access::read> depth [[texture(0)]],
                       texture2d<float, access::write> out [[texture(1)]],
                       uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= 2 || gid.y >= 2) return;
    uint2 p = uint2((gid.x + 1) * depth.get_width() / 3, (gid.y + 1) * depth.get_height() / 3);
    out.write(float4(depth.read(p).r, 0, 0, 1), gid);
}

// Pass 2: fog + bloom + radial streaks + grade + vignette, written to the target.
kernel void compositePass(texture2d<float, access::sample> src   [[texture(0)]],
                          texture2d<float, access::sample> bloomA [[texture(1)]],
                          texture2d<float, access::sample> bloomB [[texture(2)]],
                          texture2d<float, access::read>   depth  [[texture(3)]],
                          texture2d<float, access::write>  dst    [[texture(4)]],
                          constant PostUniforms &u [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 uv = (float2(gid) + 0.5) / size;

    if (u.flags.x < 0.0) {  // passthrough
        dst.write(float4(src.sample(s, uv).rgb, 1.0), gid);
        return;
    }

    float2 vp = u.vanishingTexel.xy;
    float3 color = src.sample(s, uv).rgb;

    // subtle chromatic aberration, stronger at the edges and at speed
    if (u.misc.x > 0.0) {
        float2 d = (uv - 0.5) * u.misc.x;
        color.r = src.sample(s, uv + d).r;
        color.b = src.sample(s, uv - d).b;
    }

    // depth fog (distance from the projection matrix; exponential falloff)
    if (u.flags.x > 0.5) {
        float dist;
        if (u.flags.x > 1.5) {
            // fallback when the depth buffer is unreadable: radial screen-space distance
            // toward the vanishing point approximates a straight corridor well enough
            float r = length((uv - vp) * float2(1.25, 1.0));
            dist = 2.2 / max(r, 0.015);
        } else {
            uint2 dp = uint2(uv * float2(depth.get_width(), depth.get_height()));
            dp = min(dp, uint2(depth.get_width() - 1, depth.get_height() - 1));
            float d = depth.read(dp).r;
            float denom = d + u.proj.x;
            dist = (abs(denom) < 1e-7) ? 1e6 : abs(-u.proj.y / denom);
            if (!isfinite(dist)) dist = 1e6;
        }
        float fog = 1.0 - exp(-dist * u.bloom.w);
        // horizon glow: haze is brighter near the vanishing line
        float horizon = 1.0 - saturate(abs(uv.y - vp.y) * 2.2);
        float3 fogCol = u.fogColor.rgb * (1.0 + u.fogColor.w * horizon * horizon);
        fog = min(fog, 0.92);
        color = mix(color, fogCol, fog);
    }

    // bloom
    float3 bl = bloomA.sample(s, uv).rgb + bloomB.sample(s, uv).rgb * 0.8;
    if (u.flags.y > 0.5) color += bl * u.bloom.x;

    // directional streaks: smear the bright buffer away from the vanishing point
    if (u.flags.z > 0.5 && u.bloom.y > 0.0) {
        float2 dir = uv - vp;
        float3 acc = 0.0;
        float wsum = 0.0;
        const int N = 14;
        for (int i = 1; i <= N; i++) {
            float t = float(i) / float(N);
            float w = 1.0 - t;
            acc += bloomA.sample(s, uv - dir * t * u.bloom.z).rgb * w;
            wsum += w;
        }
        acc /= wsum;
        // keep the centre (where the speeder sits) comparatively sharp
        float edge = smoothstep(0.08, 0.45, length((uv - vp) * float2(1.0, 1.6)));
        color += acc * u.bloom.y * edge;
    }

    // grade
    if (u.flags.w > 0.5) {
        float3 g = color * u.proj.z;
        g = aces(g);
        float l = luminance(g);
        g = mix(float3(l), g, u.misc.z);
        // cool lift in the shadows, slight magenta in the mids
        float shadow = 1.0 - smoothstep(0.0, 0.35, l);
        g += float3(0.004, 0.010, 0.030) * shadow * u.misc.w;
        g += float3(0.010, 0.0, 0.012) * (1.0 - abs(l - 0.5) * 2.0) * u.misc.w * 0.5;
        color = g;
    }

    // collision flash
    if (u.vanishingTexel.z > 0.0) {
        float f = u.vanishingTexel.z;
        color = mix(color, float3(1.0, 0.22, 0.25), f * 0.3);
        color += f * 0.08;
    }

    // vignette
    float v = 1.0 - u.proj.w * smoothstep(0.35, 1.25, length((uv - 0.5) * float2(1.2, 1.0)));
    color *= v;

    dst.write(float4(color, 1.0), gid);
}
