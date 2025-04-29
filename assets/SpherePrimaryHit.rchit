#include "structures.fxh"
#include "RayUtils.fxh"

// Función para generar un color basado en un valor semilla
float3 generateRandomColor(float seed) {
    // Usamos el seno para generar valores pseudo-aleatorios
    float r = frac(sin(seed * 12.9898) * 43758.5453);
    float g = frac(sin(seed * 78.233) * 43758.5453);
    float b = frac(sin(seed * 37.719) * 43758.5453);
    return float3(r, g, b);
}

[shader("closesthit")]
void main(inout PrimaryRayPayload payload, in ProceduralGeomIntersectionAttribs attr) {
    // Transform sphere normal.
    float3 normal = normalize(mul((float3x3) ObjectToWorld3x4(), attr.Normal));

    // Reflect normal.
    float3 rayDir = reflect(WorldRayDirection(), normal);

    RayDesc ray;
    ray.Origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent() + normal * SMALL_OFFSET;
    ray.TMin   = 0.0;
    ray.TMax   = 100.0;

    // Cast multiple rays that are distributed within a cone.
    float3 color = float3(0.0, 0.0, 0.0);
    const int ReflBlur = payload.Recursion > 1 ? 1 : g_ConstantsCB.SphereReflectionBlur;
    for (int j = 0; j < ReflBlur; ++j)
    {
        float2 offset = float2(g_ConstantsCB.DiscPoints[j / 2][(j % 2) * 2], g_ConstantsCB.DiscPoints[j / 2][(j % 2) * 2 + 1]);
        ray.Direction = DirectionWithinCone(rayDir, offset * 0.01);
        color += CastPrimaryRay(ray, payload.Recursion + 1).Color;
    }

    color /= float(ReflBlur);

    float4 row0 = ObjectToWorld3x4()[0];
    float4 row1 = ObjectToWorld3x4()[1];
    float4 row2 = ObjectToWorld3x4()[2];
    

    float paddingSeed = row0.w + row1.w + row2.w;

    if (abs(paddingSeed) < 0.0001) {
        float3 objectPosition = ObjectToWorld3x4()[3].xyz;
        paddingSeed = objectPosition.x + objectPosition.y + objectPosition.z;
    }
    

    float3 randomColor = generateRandomColor(paddingSeed);
    

    color *= g_ConstantsCB.SphereReflectionColorMask * randomColor;

    payload.Color = color;
    payload.Depth = RayTCurrent();
}