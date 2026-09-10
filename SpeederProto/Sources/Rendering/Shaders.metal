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
