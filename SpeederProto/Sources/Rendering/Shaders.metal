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
    if (part < 0.5) {
        gain = 0.95 + white * 1.8 + pulse * 3.0 + cp.w * 0.4;
        // thin darker seam along the middle of the wall so it reads as a panel, not a flat quad
        float seam = 0.92 + 0.08 * smoothstep(0.0, 0.08, abs(v - 0.5));
        gain *= seam;
    } else if (part < 1.5) {
        float edge = max(-v, v - 1.0);                        // 0 inside the wall, up to 0.35 outside
        float fall = 1.0 - smoothstep(0.0, 0.35, edge);
        alpha *= (0.30 + pulse * 0.5) * fall * fall;
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
