#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// Surface shader for hologram signage: rolling dark band, fine scanlines and a
// little flicker on top of the pre-rendered billboard texture.
[[visible]]
void hologramSurface(realitykit::surface_parameters params)
{
    constexpr sampler s(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;
    float t = params.uniforms().time();

    half4 c = params.textures().base_color().sample(s, uv);
    float scan = 0.88 + 0.12 * sin(uv.y * 380.0 + t * 8.0);
    float band = fract(uv.y * 0.5 - t * 0.12);
    float roll = 0.7 + 0.3 * smoothstep(0.0, 0.12, abs(band - 0.5));
    float flicker = 0.93 + 0.07 * sin(t * 41.0) * sin(t * 17.0);
    half3 col = c.rgb * half(scan * roll * flicker * 1.5);
    params.surface().set_base_color(col);
    params.surface().set_emissive_color(col * 0.5h);
}

// Light-trail ribbon (The Grid). Vertex uv0 = (arc length s, cross-section v); vertex
// colour = (r, g, b, part) with part 0 core wall, 1 glow halo, 2 floor reflection.
// custom_parameter = (head s, tail s, pulse s, boost): the fade is computed from arc
// length so the geometry never needs rewriting as the bike moves on.
[[visible]]
void trailSurface(realitykit::surface_parameters params)
{
    float2 uv = params.geometry().uv0();
    float4 vc = params.geometry().color();
    float4 cp = params.uniforms().custom_parameter();
    float s = uv.x, v = uv.y;
    float part = vc.w;
    float3 col = vc.rgb;

    float headDist = max(cp.x - s, 0.0);
    float white = exp(-headDist / 6.0);                       // near-white just behind the bike
    float tail = smoothstep(cp.y, cp.y + 14.0, s);            // fade from the oldest end
    float pulse = exp(-pow((s - cp.z) / 10.0, 2.0));          // crash pulse travelling back
    float3 hot = mix(col, float3(1.0), white * 0.85 + pulse * 0.9);

    float alpha = tail;
    float gain = 1.0;
    float t = params.uniforms().time();
    bool isStatic = cp.x > 1e5;                               // the arena's rails, ramps, hazards (TrailRenderer marks them)
    if (isStatic) {
        // dark glass (3 Oct 2026): a near-black translucent body that lets the floor read through, the
        // strand's colour only as a crisp rim along the top edge and a faint line along the base
        if (part < 0.5) {
            float rim = smoothstep(0.90, 1.0, v);
            float base = smoothstep(0.10, 0.0, v) * 0.35;
            // solid smoked panel: a dark body you cannot see through much, a faint horizontal seam, the colour at the rim
            float seam = 0.85 + 0.15 * smoothstep(0.0, 0.06, abs(v - 0.5));
            float3 glass = (col * 0.14 + float3(0.02, 0.045, 0.06)) * seam;
            float3 c = mix(glass, col, rim + base);
            float a = 0.84 + rim * 0.16;
            params.surface().set_emissive_color(half3(c * (0.9 + rim * 2.6 + base * 0.8)));
            params.surface().set_base_color(half3(0.0));
            params.surface().set_opacity(half(a));
            return;
        } else if (part < 1.5) {
            float edge = max(-v, v - 1.0);
            float fall = 1.0 - smoothstep(0.0, 0.35, edge);
            float topOnly = smoothstep(0.7, 1.0, v);           // the glow hugs the rim, not the body
            params.surface().set_emissive_color(half3(col * 1.2));
            params.surface().set_base_color(half3(0.0));
            params.surface().set_opacity(half(0.16 * fall * fall * topOnly));
            return;
        } else {
            float fall = pow(saturate(1.0 - abs(v)), 1.6);
            params.surface().set_emissive_color(half3(col * 0.8));
            params.surface().set_base_color(half3(0.0));
            params.surface().set_opacity(half(0.06 * fall));
            return;
        }
    }
    if (part < 0.5) {
        // the wall is hot, not glass (Tron: Ares): a bright rim along the top edge, a faint heat
        // flicker running along it, and a translucent body so the arena reads through it
        float rim = smoothstep(0.80, 1.0, v) + smoothstep(0.2, 0.0, v) * 0.5;
        float flicker = 0.94 + 0.06 * sin(s * 1.3 - t * 14.0) * sin(v * 9.0 + t * 5.0);
        gain = (0.85 + white * 1.8 + pulse * 3.0 + cp.w * 0.4 + rim * 1.4) * flicker;
        hot = mix(hot, float3(1.0), rim * 0.35);
        // thin darker seam along the middle of the wall so it reads as a panel, not a flat quad
        float seam = 0.92 + 0.08 * smoothstep(0.0, 0.08, abs(v - 0.5));
        gain *= seam;
        alpha *= 0.82 + rim * 0.18;
    } else if (part < 1.5) {
        float edge = max(-v, v - 1.0);                        // 0 inside the wall, up to 0.35 outside
        float fall = 1.0 - smoothstep(0.0, 0.35, edge);
        float shimmer = 0.85 + 0.15 * sin(s * 0.7 + t * 9.0 + v * 6.0);
        alpha *= (0.30 + pulse * 0.5) * fall * fall * shimmer;
        gain = 1.0 + white * 0.6;
    } else {
        float fall = pow(saturate(1.0 - abs(v)), 1.6);
        alpha *= (0.20 + white * 0.25 + pulse * 0.4) * fall;
        gain = 0.9;
    }
    half3 out = half3(hot * gain);
    params.surface().set_base_color(out);
    params.surface().set_emissive_color(out);
    params.surface().set_opacity(half(alpha));
}

// Derez dissolve for a light cycle: the mesh burns away along a 3D noise threshold that the
// custom parameter drives (x: progress 0...1), with a hot rim in the cycle's colour (y, z, w).
static inline float hash3(float3 p) {
    p = fract(p * 0.3183099 + float3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
static inline float noise3(float3 x) {
    float3 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i + float3(1, 0, 0)), f.x), mix(hash3(i + float3(0, 1, 0)), hash3(i + float3(1, 1, 0)), f.x), f.y),
               mix(mix(hash3(i + float3(0, 0, 1)), hash3(i + float3(1, 0, 1)), f.x), mix(hash3(i + float3(0, 1, 1)), hash3(i + float3(1, 1, 1)), f.x), f.y), f.z);
}

[[visible]]
void dissolveSurface(realitykit::surface_parameters params)
{
    constexpr sampler smp(filter::linear, address::repeat);
    auto tex = params.textures();
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;
    half3 tint = half3(params.material_constants().base_color_tint());
    half3 base = tex.base_color().sample(smp, uv).rgb * tint;
    float4 cp = params.uniforms().custom_parameter();
    float3 p = params.geometry().model_position();
    float n = noise3(p * 9.0) * 0.7 + noise3(p * 31.0) * 0.3;
    float a = n - cp.x * 1.15;
    float edge = 1.0 - smoothstep(0.0, 0.14, a);
    half3 glow = half3(cp.y, cp.z, cp.w) * half(edge * 5.0);
    params.surface().set_base_color(mix(base, half3(1.0), half(edge * 0.6)));
    params.surface().set_emissive_color(glow);
    params.surface().set_roughness(half(0.45));
    params.surface().set_metallic(half(0.3));
    params.surface().set_opacity(a < 0.0 ? half(0.0) : half(1.0));
}
