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
    float4 section;         // x: enclosure (0 open, 1 tunnel/conduit)  y: curtain (0 clear, 1 black)  z: kick  w: boost level
    float4 haze;            // x,y: thruster position (uv)  z: haze strength  w: radius
    float4 extra;           // x: lightning  y: dither  z: lens FX  w: motion blur (metres per frame x shutter)
    float4 vehicle;         // x,y: vehicle centre (uv)  z: its distance (m)  w: mask radius
    float4 weather;         // x: rain strength  y: rain speed (rows per second)  z: fog cap (the backdrop keeps the rest)
};

// colour fetch with the chromatic offset baked in, so blur taps and the base sample split the same way
static inline float3 fetchCA(texture2d<float, access::sample> src, sampler s, float2 uv, float2 d) {
    return float3(src.sample(s, uv + d).r, src.sample(s, uv).g, src.sample(s, uv - d).b);
}

static inline float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
static inline float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + float2(1, 0)), c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

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
                          texture2d<float, access::sample> dirt   [[texture(5)]],
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
    float boost = u.section.w;
    float aspect = size.x / size.y;

    // linear distance for this pixel (depth buffer, or the radial estimate when depth is unreadable)
    float dist;
    if (u.flags.x > 1.5 || u.flags.x < 0.5) {
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

    // the vehicle: a soft mask around its screen position, and its distance; effects that belong to
    // the world (blur, haze) stop at it, since it is the one thing that does not move past the camera
    float2 vd = (uv - u.vehicle.xy) * float2(aspect, 1.0);
    float vehicleMask = 1.0 - smoothstep(u.vehicle.w * 0.45, u.vehicle.w, length(vd));
    bool behindVehicle = dist > u.vehicle.z + 1.0;

    // thruster heat haze: rising, scrolling refraction around the exhaust, only on what is behind it
    if (u.haze.z > 0.0 && behindVehicle) {
        float2 hd = (uv - u.haze.xy) * float2(aspect, 1.0);
        float m = (1.0 - smoothstep(0.0, u.haze.w, length(hd))) * u.haze.z;
        if (m > 0.001) {
            float t = u.misc.y;
            float2 n = float2(vnoise(uv * float2(60, 30) + float2(0, t * 9.0)), vnoise(uv * float2(50, 40) + float2(t * 7.0, t * 6.0))) - 0.5;
            uv += n * 0.02 * m;
        }
    }

    // chromatic offset, stronger at the edges and at speed (applied inside every sample)
    float2 ca = (uv - 0.5) * u.misc.x;
    float3 color = fetchCA(src, s, uv, ca);

    // motion blur by reprojection: the world moves rigidly toward the camera, so last frame this
    // point was `travel` further away; the blur runs from here toward where it was, longer for
    // near pixels, never on the vehicle or at the centre (Thumper keeps the centre sharp)
    if (u.extra.w > 0.0 && (behindVehicle || vehicleMask < 0.01)) {
        float2 dir = uv - vp;
        float edge = smoothstep(0.05, 0.42, length(dir * float2(1.0, 1.5)));
        float travel = u.extra.w;
        float k = travel / (dist + travel);
        float2 delta = dir * min(k, 0.045) * edge * (1.0 - vehicleMask);
        if (length(delta * size) > 1.0) {
            float3 acc = 0.0;
            const int N = 6;
            for (int i = 0; i < N; i++) {
                float t = (float(i) + 0.5) / float(N);
                acc += fetchCA(src, s, uv - delta * t, ca);
            }
            color = acc / float(N);
        }
    }

    // depth fog (exponential falloff on the linear distance)
    if (u.flags.x > 0.5) {
        float fog = 1.0 - exp(-dist * u.bloom.w);
        // horizon glow: haze is brighter near the vanishing line; inside a tunnel or conduit the
        // haze darkens and the glow goes away, blended over the section lead-in
        float enc = u.section.x;
        float horizon = 1.0 - saturate(abs(uv.y - vp.y) * 2.2);
        float3 fogCol = mix(u.fogColor.rgb, u.fogColor.rgb * 0.35, enc) * (1.0 + u.fogColor.w * (1.0 - enc) * horizon * horizon);
        fogCol += u.extra.x * float3(0.18, 0.22, 0.34) * (1.0 - enc);   // lightning lights the haze first
        fog = min(fog, u.weather.z > 0.0 ? u.weather.z : 0.92);
        color = mix(color, fogCol, fog);
    }
    // lightning: a cool lift over everything outside the tunnels for a couple of frames
    color += u.extra.x * float3(0.07, 0.09, 0.16) * (1.0 - u.section.x);

    // rain: two screen-space layers of thin streaks falling with a slight slant (near: wider, faster);
    // a hash per cell decides whether it holds a streak, so the pattern never repeats visibly
    if (u.weather.x > 0.001) {
        float t = u.misc.y;
        float rain = 0.0;
        for (int k = 0; k < 2; k++) {
            float cols = k == 0 ? 70.0 : 150.0;
            float rows = cols * 0.22;
            float2 p = float2(uv.x * cols + uv.y * (k == 0 ? 3.0 : 5.0), uv.y * rows - t * u.weather.y * (k == 0 ? 1.0 : 0.7));   // minus: texture y runs down, so the streaks fall
            float2 cell = floor(p), f = fract(p);
            float h = hash21(cell + float(k) * 17.0);
            if (h < (k == 0 ? 0.16 : 0.22)) {
                float cx = 0.2 + 0.6 * fract(h * 13.7);
                float w = k == 0 ? 0.05 : 0.10;
                float streak = (1.0 - smoothstep(0.0, w, abs(f.x - cx))) * smoothstep(0.0, 0.2, f.y) * smoothstep(1.0, 0.6, f.y);
                rain += streak * (k == 0 ? 0.30 : 0.16);
            }
        }
        color += rain * float3(0.62, 0.76, 1.0) * u.weather.x * (1.0 - u.section.x);
    }

    // bloom
    float3 bl = bloomA.sample(s, uv).rgb + bloomB.sample(s, uv).rgb * 0.8;
    if (u.flags.y > 0.5) color += bl * u.bloom.x;

    // lens: ghost flares mirrored through the centre from the wide bloom, and dirt that lights up with it
    if (u.flags.y > 0.5 && u.extra.z > 0.0) {
        float2 c = uv - 0.5;
        float3 gh = bloomB.sample(s, 0.5 - c * 0.55).rgb * float3(0.6, 0.9, 1.0) * 0.30
                  + bloomB.sample(s, 0.5 - c * 1.30).rgb * float3(1.0, 0.6, 0.9) * 0.22
                  + bloomB.sample(s, 0.5 - c * 2.10).rgb * float3(1.0, 0.95, 0.8) * 0.16;
        float fall = 1.0 - smoothstep(0.15, 0.85, length(c));
        color += gh * u.extra.z * fall;
        float dm = dirt.sample(s, uv).r;
        color += bloomB.sample(s, uv).rgb * dm * u.extra.z * 1.1;
    }

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
        // centre-weighted grade (Thumper): the centre keeps its colour and lifts a touch, the outer ring
        // desaturates and darkens; subtle at cruise, stronger under boost so the frame tunnels
        float rc = length((uv - 0.5) * float2(1.25, 1.0));
        float centre = 1.0 - smoothstep(0.2, 0.85, rc);
        float weight = 0.06 + boost * 0.30;
        float sat = u.misc.z * (1.0 - weight * 0.8 * (1.0 - centre));
        g = mix(float3(l), g, sat);
        g *= 1.0 + weight * (0.22 * centre - 0.6 * (1.0 - centre));
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

    // vignette (tighter inside enclosed sections)
    float v = 1.0 - u.proj.w * (1.0 + 0.6 * u.section.x + 0.45 * boost) * smoothstep(0.35 - 0.08 * boost, 1.25, length((uv - 0.5) * float2(1.2, 1.0)));
    color *= v;

    // curtain: fade to black over rebuilds and the launch
    color *= 1.0 - u.section.y;

    // dither (interleaved gradient noise) so the dark worlds do not band in the fog and the sky
    float n = fract(52.9829189 * fract(0.06711056 * float(gid.x) + 0.00583715 * float(gid.y)));
    color += (n - 0.5) * (u.extra.y * 1.5 / 255.0);

    dst.write(float4(color, 1.0), gid);
}
