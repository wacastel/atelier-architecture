#include <metal_stdlib>
#include <metal_raytracing>
using namespace metal;
using namespace raytracing;

// This ABI is shared with SceneTypes.swift. Each field has 16-byte alignment.
struct SceneVertex { float4 position; float4 normal; };
struct SceneMaterial { float4 albedo; float4 properties; };
struct SceneLight { float4 positionRadius; float4 directionCone; float4 colorPower; float4 parameters; };
struct FrameUniforms {
    float4 origin, right, up, forward, sunDirection, sunColor;
    uint4 viewport;
    float4 settings;
};

constant float PI = 3.14159265358979323846f;

uint hashBits(uint x) {
    x ^= x >> 16; x *= 0x7feb352du;
    x ^= x >> 15; x *= 0x846ca68bu;
    return x ^ (x >> 16);
}
float randomFloat(thread uint &state) {
    state = hashBits(state + 0x9e3779b9u);
    return float(state >> 8) * (1.0f / 16777216.0f);
}
float noiseCell(float3 p) {
    int3 q = int3(floor(p));
    uint h = hashBits(as_type<uint>(q.x) ^ hashBits(as_type<uint>(q.y)) ^ hashBits(as_type<uint>(q.z) + 113u));
    return float(h >> 8) * (1.0f / 16777216.0f);
}
float smoothNoise(float3 p) {
    float3 i = floor(p), f = fract(p);
    f = f * f * (3.0f - 2.0f * f);
    return mix(mix(mix(noiseCell(i), noiseCell(i + float3(1,0,0)), f.x),
                   mix(noiseCell(i + float3(0,1,0)), noiseCell(i + float3(1,1,0)), f.x), f.y),
               mix(mix(noiseCell(i + float3(0,0,1)), noiseCell(i + float3(1,0,1)), f.x),
                   mix(noiseCell(i + float3(0,1,1)), noiseCell(i + float3(1,1,1)), f.x), f.y), f.z);
}
float maxComponent(float3 v) { return max(v.x, max(v.y, v.z)); }
float luminance(float3 c) { return dot(c, float3(0.2126f, 0.7152f, 0.0722f)); }

void basis(float3 n, thread float3 &t, thread float3 &b) {
    t = normalize(cross(abs(n.y) < 0.98f ? float3(0,1,0) : float3(1,0,0), n));
    b = cross(n, t);
}
float3 localToWorld(float3 v, float3 n) {
    float3 t, b; basis(n, t, b);
    return normalize(v.x * t + v.y * b + v.z * n);
}
float3 cosineDirection(float3 n, float2 xi) {
    float r = sqrt(xi.x), phi = 2.0f * PI * xi.y;
    return localToWorld(float3(r * cos(phi), r * sin(phi), sqrt(1.0f - xi.x)), n);
}
float3 sunSample(float3 direction, float radius, float2 xi) {
    float3 t, b; basis(direction, t, b);
    float r = radius * sqrt(xi.x), phi = 2.0f * PI * xi.y;
    return normalize(direction + r * (cos(phi) * t + sin(phi) * b));
}

// Analytic clear daylight. The solar disc is evaluated only for camera rays:
// direct-light next-event estimation already accounts for sunlight at surfaces.
float3 skyRadiance(float3 d, constant FrameUniforms &u, bool cameraRay) {
    if (u.sunColor.w > 0.5f) {
        // Photographic night: navy zenith, restrained amber urban horizon.
        // Values are linear radiance, not a blue daylight sky with lower exposure.
        float h = max(d.y, 0.0f);
        float3 sky = mix(float3(0.014f,0.019f,0.036f),float3(0.0017f,0.0042f,0.013f),pow(h,0.43f));
        sky += float3(0.012f,0.0048f,0.0011f)*exp(-h*22.0f);
        return sky * max(u.settings.w,0.0f);
    }
    float h = max(d.y, 0.0f);
    float3 horizon = float3(0.67f, 0.79f, 0.96f);
    float3 zenith = float3(0.14f, 0.36f, 0.72f);
    float3 sky = mix(horizon, zenith, pow(h, 0.45f));
    float mu = clamp(dot(d, normalize(u.sunDirection.xyz)), -1.0f, 1.0f);
    float aureole = pow(max(mu, 0.0f), 28.0f);
    sky += float3(0.28f, 0.21f, 0.12f) * aureole;
    if (d.y < 0.0f) sky = mix(horizon * 0.55f, float3(0.14f, 0.17f, 0.19f), min(-d.y * 3.0f, 1.0f));
    sky *= max(u.settings.w, 0.0f);
    if (cameraRay) {
        float angularRadius = max(u.settings.z, 0.002f);
        float disk = smoothstep(cos(angularRadius * 1.15f), cos(angularRadius * 0.85f), mu);
        sky += u.sunColor.xyz * disk * 6.0f;
    }
    return sky;
}

struct Surface { float3 color; float roughness; float metallic; float emission; float dielectricF0; float3 normal; };
Surface surfaceAt(SceneMaterial material, float3 p, float3 n, float footprint, bool night) {
    Surface s;
    s.color = material.albedo.rgb;
    s.roughness = clamp(material.albedo.w, 0.065f, 1.0f);
    s.metallic = saturate(material.properties.x);
    s.emission = max(material.properties.y, 0.0f);
    s.normal = n;
    s.dielectricF0 = 0.04f;
    int pattern = int(material.properties.z + 0.5f);
    float closeDetail = 1.0f - smoothstep(0.012f, 0.09f, footprint);
    if (pattern == 1) {
        // Half-metre dressed paving blocks, staggered by row; millimetre joints.
        float2 coord = abs(n.y) > 0.65f ? p.xz : (abs(n.z) > 0.65f ? p.xy : p.zy);
        float2 q = coord / float2(0.72f, 0.46f);
        q.x += (int(floor(q.y)) & 1) ? 0.5f : 0.0f;
        float2 edge = min(fract(q), 1.0f - fract(q)) * float2(0.72f, 0.46f);
        float joint = 1.0f - smoothstep(0.004f, 0.009f + footprint * 0.45f, min(edge.x, edge.y));
        float stone = noiseCell(float3(floor(q), 31.0f));
        s.color *= mix(0.88f, 1.12f, stone);
        s.color *= 1.0f - joint * 0.28f * (1.0f - smoothstep(0.08f, 0.5f, footprint));
        if (closeDetail > 0.0f) s.color *= 1.0f + (smoothNoise(p * 140.0f) - 0.5f) * 0.12f * closeDetail;
    } else if (pattern == 2) {
        // Painted iron retains the original material hue; fine coating variation
        // is filtered out once smaller than a camera pixel to avoid shimmer.
        float weather = smoothNoise(p * 0.7f);
        s.color *= 0.92f + 0.16f * weather;
        if (closeDetail > 0.0f) {
            float grain = smoothNoise(p * 180.0f) - 0.5f;
            s.color *= 1.0f + grain * 0.16f * closeDetail;
            s.roughness = clamp(s.roughness + grain * 0.14f * closeDetail, 0.09f, 1.0f);
            float3 perturb = float3(smoothNoise(p * 96.0f + 31.0f), smoothNoise(p * 96.0f + 63.0f), grain) - 0.5f;
            s.normal = normalize(n + (perturb - n * dot(perturb, n)) * 0.035f * closeDetail);
        }
    } else if (pattern == 3) {
        float plank = floor(p.z / 0.17f);
        float grain = smoothNoise(float3(p.x * 0.7f, plank * 3.0f, p.z * 90.0f));
        s.color *= 0.86f + 0.28f * grain;
        float edge = min(fract(p.z / 0.17f), 1.0f - fract(p.z / 0.17f)) * 0.17f;
        s.color *= 1.0f - (1.0f - smoothstep(0.002f, 0.004f + footprint * 0.3f, edge)) * 0.3f * closeDetail;
    } else if (pattern == 4) {
        float patch = smoothNoise(p * 0.65f);
        s.color *= mix(float3(0.78f, 0.91f, 0.69f), float3(1.08f, 1.06f, 0.87f), patch);
        if (closeDetail > 0.0f) s.color *= 1.0f + (noiseCell(p * 110.0f) - 0.5f) * 0.2f * closeDetail;
    } else if (pattern == 5) {
        float seam = abs(fract(p.x * 1.6f) - 0.5f);
        s.color *= 0.90f + 0.14f * smoothNoise(p * 0.4f);
        s.color *= 1.0f - smoothstep(0.47f, 0.49f, seam) * 0.16f * closeDetail;
    } else if (pattern == 6 || pattern == 7) {
        // Deliberately opaque reflective glazing. No transmission is claimed.
        s.metallic = max(s.metallic, 0.75f);
        s.roughness = min(s.roughness, 0.13f);
        if (pattern == 7 && night) {
            float room = noiseCell(float3(floor(p.x/2.9f),floor(p.y/3.4f),floor(p.z/2.9f)));
            if (room > 0.64f) {
                s.color = mix(float3(1.0f,0.49f,0.16f),float3(1.0f,0.78f,0.45f),room);
                s.emission = 0.12f + room*0.32f;
                s.metallic = 0.0f;
            }
        }
    } else if (pattern == 15) {
        // Steady architectural antenna illumination. The white skin remains
        // visible along the complete mast, with separate red obstruction lamps.
        s.emission=night ? clamp(material.properties.y,0.0f,1.0f):0.0f;
        if(night) s.color=float3(0.80f,0.88f,1.0f);
    } else if (pattern == 14) {
        // Chicago room occupancy is chosen per modeled window, preserving pane
        // boundaries instead of cutting world-space noise through glazing.
        float power=s.emission;
        s.emission=0; s.metallic=max(s.metallic,0.72f); s.roughness=0.13f;
        if(night && power>0) {
            s.color=power<0.105f ? float3(1.0f,0.73f,0.46f)
                : power<0.16f ? float3(1.0f,0.87f,0.68f):float3(0.76f,0.86f,1.0f);
            s.emission=power;s.metallic=0.03f;
        }
    } else if (pattern == 13) {
        // Willis curtain wall: three 1.524m bays between the 4.572m columns,
        // grouped into occupied offices, aligned to the model's mapped setback and published observation levels.
        s.metallic=max(s.metallic,0.72f); s.roughness=0.115f;
        if(night) {
            float horizontal=abs(n.x)>0.65f ? p.z:p.x;
            float floorIndex=p.y<200.0f ? p.y/4.0f : p.y<260.0f ? 50+(p.y-200)/3.75f : p.y<355 ? 66+(p.y-260)/(95.0f/24.0f) : p.y<412.3944f ? 90+(p.y-355)/(57.3944f/13.0f) : p.y<435 ? 103+(p.y-412.3944f)/(22.6056f/5.0f) : 108+(p.y-435)/3.57f;
            float room=noiseCell(float3(floor((horizontal+34.29f)/3.048f),floor(floorIndex),abs(n.x)>0.65f ? 131:173));
            if(room>0.66f) {
                s.color=room>0.89f ? float3(0.76f,0.85f,0.97f):mix(float3(1.0f,0.66f,0.34f),float3(1.0f,0.87f,0.63f),room);
                s.emission=0.12f+0.27f*room; s.metallic=0.04f;
            }
        }
    } else if (pattern == 8) {
        s.emission = night ? 10.0f : 0.3f;
    } else if (pattern == 9) {
        // Water is dielectric (IOR 1.333, F0 2.04%). The wavelengths and their
        // gradients are in metres; analytical footprint attenuation prevents
        // unresolved ripples from crawling through the temporal reconstruction.
        float2 q = p.xz;
        float2 slope = 0;
        const float2 directions[6] = {float2(0.96f,0.28f),float2(0.89f,0.456f),float2(0.985f,0.173f),float2(0.941f,0.338f),float2(0.977f,0.213f),float2(0.907f,0.421f)};
        const float wavelengths[6] = {7.2f,3.83f,1.67f,0.73f,0.287f,0.127f};
        const float amplitudes[6] = {0.037f,0.023f,0.013f,0.0052f,0.0021f,0.00065f};
        // Coherent wind direction with slowly varying phase/amplitude fields.
        // Compute their derivatives as well, so the normal is the gradient of
        // the warped height field instead of a grid of unrelated sine normals.
        float2 warpA=float2(0.071f,0.113f),warpB=float2(-0.097f,0.059f);
        float wa=dot(q,warpA),wb=dot(q,warpB);
        float warp=2.7f*sin(wa)+1.9f*sin(wb);
        float2 warpGradient=2.7f*cos(wa)*warpA+1.9f*cos(wb)*warpB;
        for (uint j=0;j<6;++j) {
            float k=2.0f*PI/wavelengths[j];
            float attenuation=exp(-0.5f*pow(k*footprint*0.60f,2.0f));
            float warpScale=0.35f+float(j)*0.19f;
            float phase=k*dot(q,directions[j])+float(j)*2.17f+warp*warpScale;
            float amplitudeField=0.72f+0.28f*sin(wa*0.57f+float(j)*1.27f);
            float2 amplitudeGradient=0.28f*cos(wa*0.57f+float(j)*1.27f)*warpA*0.57f;
            slope += amplitudes[j]*attenuation*(amplitudeField*cos(phase)*(directions[j]*k+warpGradient*warpScale)+sin(phase)*amplitudeGradient);
        }
        s.normal=normalize(float3(-slope.x,1.0f,-slope.y));
        s.metallic=0.0f; s.dielectricF0=0.02037f;
        float deep=0.87f+0.13f*smoothNoise(float3(q*0.027f,41));
        s.color*=deep;
        s.roughness=0.095f+0.055f*smoothstep(0.04f,0.6f,footprint);
    } else if (pattern == 10) {
        // Larger limestone ashlar blocks, staggered joints, weathered riverline.
        float2 coord=abs(n.y)>0.65f ? p.xz : (abs(n.x)>0.65f ? p.zy:p.xy);
        float2 q=coord/float2(1.18f,0.48f);
        q.x += (int(floor(q.y))&1) ? 0.5f:0.0f;
        float2 edge=min(fract(q),1.0f-fract(q))*float2(1.18f,0.48f);
        float joint=1.0f-smoothstep(0.004f,0.011f+footprint*0.35f,min(edge.x,edge.y));
        s.color*=0.88f+0.21f*noiseCell(float3(floor(q),27));
        s.color*=1.0f-0.34f*joint*(1.0f-smoothstep(0.13f,0.65f,footprint));
        float stain=(1.0f-smoothstep(-5.0f,-2.8f,p.y))*(0.6f+0.4f*smoothNoise(p*0.85f));
        s.color*=mix(float3(1),float3(0.50f,0.57f,0.40f),stain);
        s.color*=1.0f+(smoothNoise(p*86.0f)-0.5f)*0.13f*closeDetail;
    } else if (pattern == 11) {
        s.color*=0.90f+0.20f*smoothNoise(p*2.7f);
        s.color*=1.0f+(noiseCell(p*130.0f)-0.5f)*0.19f*closeDetail;
        if(night) { s.color*=0.55f; s.roughness=0.27f; }
    } else if (pattern == 12) {
        // Tinted panoramic boat glazing. Opaque architectural glass proxy,
        // matching the engine's glass convention, with warm cabin light at night.
        s.metallic=0.60f; s.roughness=0.10f;
        if(night) {
            float room=0.78f+0.22f*smoothNoise(float3(p.x*0.20f,17,p.z*0.21f));
            s.color=float3(0.76f,0.49f,0.235f);
            s.metallic=0.42f;
            s.emission=room*(0.14f+0.09f*(1.0f-smoothstep(-3.3f,-1.3f,p.y)));
        }
    }
    if (night && pattern == 1 && n.y > 0.8f && p.y < 2.1f) {
        // Rain-darkened stone with broad, smooth puddles. Water stays dielectric;
        // its grazing Fresnel reflection comes from the actual lit scene rays.
        float puddle = smoothstep(0.40f,0.61f,smoothNoise(float3(p.x*0.11f,9.0f,p.z*0.11f)));
        s.color *= mix(0.62f,0.32f,puddle);
        s.roughness = mix(0.24f,0.078f,puddle);
        s.metallic = 0.0f;
    }
    s.color = clamp(s.color, float3(0.001f), float3(0.97f));
    return s;
}

// Parallel thin glass sheets: exact unpolarized air/glass Fresnel (IOR 1.5),
// including the infinite sequence of internal reflections, R_sheet = 2R/(1+R).
// Transmission leaves parallel to the incident ray; no solid-volume refraction
// or caustic focusing is implied. Geometry supplies a single optical sheet.
float thinSheetReflectance(float cosine) {
    float c = clamp(abs(cosine), 0.00001f, 1.0f);
    float ct = sqrt(max(0.0f, 1.0f-(1.0f-c*c)/2.25f));
    float rp = (1.5f*c-ct)/(1.5f*c+ct);
    float rs = (c-1.5f*ct)/(c+1.5f*ct);
    float r = 0.5f*(rp*rp+rs*rs);
    return 2.0f*r/(1.0f+r);
}
float3 glassVisibility(ray visibility, primitive_acceleration_structure scene,
                       const device SceneVertex *vertices,
                       const device uint *materialIndices,
                       const device SceneMaterial *materials) {
    intersector<triangle_data> trace;
    trace.assume_geometry_type(geometry_type::triangle);
    trace.force_opacity(forced_opacity::opaque);
    float3 transmission = 1;
    for (uint layer=0; layer<16; ++layer) {
        auto hit = trace.intersect(visibility,scene);
        if (hit.type==intersection_type::none) return transmission;
        SceneMaterial m=materials[materialIndices[hit.primitive_id]];
        if (m.properties.w<=0) return 0;
        uint i=hit.primitive_id*3;
        float3 n=normalize(cross(vertices[i+1].position.xyz-vertices[i].position.xyz,
                                 vertices[i+2].position.xyz-vertices[i].position.xyz));
        transmission *= clamp(m.albedo.rgb,0.0f,1.0f)*saturate(m.properties.w)
            *(1.0f-thinSheetReflectance(dot(n,visibility.direction)));
        if (maxComponent(transmission)<0.0001f) return 0;
        float3 p=visibility.origin+visibility.direction*hit.distance;
        float offset=max(0.001f,maxComponent(abs(p))*0.000008f);
        float step=hit.distance+offset;
        if (step>=visibility.max_distance) return transmission;
        visibility.origin += visibility.direction*step;
        visibility.max_distance -= step;
        visibility.min_distance=offset*0.25f;
    }
    return 0; // bounded traversal: unresolved deep stacks remain occluded
}

// Deterministic center-pixel geometry guides. Radiance retains subpixel jitter;
// these stable world-space guides enable motion reprojection without averaging
// depth, normals or material IDs across edges of fine ironwork.
kernel void primarySurface(texture2d<float, access::write> worldPosition [[texture(0)]],
                           texture2d<float, access::write> normalDepth [[texture(1)]],
                           texture2d<float, access::write> albedoRoughness [[texture(2)]],
                           constant FrameUniforms &u [[buffer(0)]],
                           const device SceneVertex *vertices [[buffer(1)]],
                           const device uint *materialIndices [[buffer(2)]],
                           const device SceneMaterial *materials [[buffer(3)]],
                           primitive_acceleration_structure scene [[buffer(4)]],
                           uint2 tid [[thread_position_in_grid]]) {
    if (any(tid >= u.viewport.xy)) return;
    float2 screen = (float2(tid)+0.5f)/float2(u.viewport.xy)*2.0f-1.0f;
    ray primary;
    primary.origin = u.origin.xyz;
    primary.direction = normalize(u.forward.xyz+screen.x*u.right.xyz-screen.y*u.up.xyz);
    primary.min_distance = 0.001f; primary.max_distance = 100000.0f;
    intersector<triangle_data> trace;
    trace.assume_geometry_type(geometry_type::triangle);
    trace.force_opacity(forced_opacity::opaque);
    auto hit = trace.intersect(primary,scene);
    bool throughGlass=false;
    for (uint layer=0; layer<16 && hit.type!=intersection_type::none; ++layer) {
        if (materials[materialIndices[hit.primitive_id]].properties.w<=0) break;
        throughGlass=true;
        float3 p=primary.origin+primary.direction*hit.distance;
        float offset=max(0.001f,maxComponent(abs(p))*0.000008f);
        primary.origin=p+primary.direction*offset;
        hit=trace.intersect(primary,scene);
    }
    if (hit.type == intersection_type::none) {
        worldPosition.write(float4(primary.direction,-1.0f),tid);
        normalDepth.write(float4(0,0,0,60000),tid);
        albedoRoughness.write(float4(0,0,0,1),tid);
        return;
    }
    uint i = hit.primitive_id*3;
    SceneVertex a = vertices[i], b = vertices[i+1], c = vertices[i+2];
    float3 weights = float3(1.0f-hit.triangle_barycentric_coord.x-hit.triangle_barycentric_coord.y,hit.triangle_barycentric_coord);
    float3 p = a.position.xyz*weights.x+b.position.xyz*weights.y+c.position.xyz*weights.z;
    float3 n = normalize(cross(b.position.xyz-a.position.xyz,c.position.xyz-a.position.xyz));
    if (dot(n,primary.direction)>0.0f) n = -n;
    uint material = materialIndices[hit.primitive_id];
    float depth=distance(p,u.origin.xyz);
    float footprint = depth*2.0f*length(u.up.xyz)/float(u.viewport.y);
    Surface s = surfaceAt(materials[material],p,n,footprint,u.sunColor.w>0.5f);
    // Emissive subpixel windows/fixtures need current coverage, not relit
    // surface history. Preserve the material ID with a half-unit guide flag.
    worldPosition.write(float4(p,float(material)+(s.emission>0.0f ? 0.5f : throughGlass ? 0.75f:0.0f)),tid);
    normalDepth.write(float4(n,depth),tid);
    albedoRoughness.write(float4(s.color,s.roughness),tid);
}

float3 fresnelSchlick(float cosTheta, float3 f0) {
    float x = pow(1.0f - saturate(cosTheta), 5.0f);
    return f0 + (1.0f - f0) * x;
}
float ggxDistribution(float noH, float alpha) {
    float a2 = alpha * alpha;
    float d = noH * noH * (a2 - 1.0f) + 1.0f;
    return a2 / max(PI * d * d, 1e-8f);
}
float smithG1(float noV, float alpha) {
    return 2.0f * noV / max(noV + sqrt(alpha * alpha + (1.0f - alpha * alpha) * noV * noV), 1e-6f);
}
Surface regularizeSurface(Surface surface, bool hasNonDeltaScatter) {
    // PBRT-style path regularization: only broaden a secondary narrow GGX
    // lobe after an ordinary (non-delta) scatter. Camera-visible materials and
    // perfect-sheet reflection/transmission retain their original roughness.
    float alpha = surface.roughness * surface.roughness;
    if (hasNonDeltaScatter && alpha < 0.3f)
        surface.roughness = sqrt(clamp(2.0f * alpha, 0.1f, 0.3f));
    return surface;
}
float3 brdf(Surface s, float3 v, float3 l) {
    float noV = max(dot(s.normal, v), 1e-5f), noL = max(dot(s.normal, l), 1e-5f);
    float3 h = normalize(v + l);
    float alpha = s.roughness * s.roughness;
    float3 f = fresnelSchlick(max(dot(v, h), 0.0f), mix(float3(s.dielectricF0), s.color, s.metallic));
    float3 spec = f * ggxDistribution(max(dot(s.normal, h), 0.0f), alpha)
        * smithG1(noV, alpha) * smithG1(noL, alpha) / (4.0f * noV * noL);
    return (1.0f - f) * (1.0f - s.metallic) * s.color / PI + spec;
}
float3 sampleBRDF(Surface s, float3 v, float2 xi, float choose, thread float &pdf) {
    float specProbability = mix(s.roughness < 0.2f ? 0.65f : 0.25f, 0.9f, s.metallic);
    float3 l;
    float alpha = s.roughness * s.roughness;
    if (choose < specProbability) {
        // Visible-normal GGX importance sampling (Heitz, JCGT 2018).
        // Sampling the projected visible hemisphere avoids large grazing-angle
        // weights that otherwise cause fireflies on rivets and wet paving.
        float3 tangent,bitangent; basis(s.normal,tangent,bitangent);
        float3 stretched = normalize(float3(alpha*dot(v,tangent),alpha*dot(v,bitangent),max(dot(v,s.normal),1e-5f)));
        float3 horizontal = dot(stretched.xy,stretched.xy)>1e-8f ? normalize(float3(-stretched.y,stretched.x,0)) : float3(1,0,0);
        float3 vertical = cross(stretched,horizontal);
        float radius = sqrt(xi.x), angle = 2.0f*PI*xi.y;
        float diskX = radius*cos(angle), diskY = radius*sin(angle);
        diskY = mix(sqrt(max(0.0f,1.0f-diskX*diskX)),diskY,0.5f*(1.0f+stretched.z));
        float3 projected = horizontal*diskX+vertical*diskY+stretched*sqrt(max(0.0f,1.0f-diskX*diskX-diskY*diskY));
        float3 local = normalize(float3(projected.xy*alpha,max(projected.z,0.0f)));
        float3 h = normalize(tangent*local.x+bitangent*local.y+s.normal*local.z);
        l = reflect(-v, h);
    } else {
        l = cosineDirection(s.normal, xi);
    }
    float noL = max(dot(s.normal, l), 0.0f);
    float3 h = normalize(v + l);
    float noH = max(dot(s.normal, h), 0.0f);
    float noV = max(dot(s.normal,v),1e-5f);
    float specPDF = ggxDistribution(noH,alpha)*smithG1(noV,alpha)/(4.0f*noV);
    pdf = mix(noL / PI, specPDF, specProbability);
    return l;
}

struct DirectSample {
    float3 direction;
    float3 value;
    float distance, radius, weight;
};
DirectSample evaluateLight(SceneLight light, Surface surface, float3 p, float3 v, float3 geometricNormal) {
    DirectSample sample;
    sample.direction = float3(0,1,0); sample.value = 0;
    sample.distance = 1; sample.radius = 0; sample.weight = 0;
    float3 delta = light.positionRadius.xyz-p;
    float distanceSquared = dot(delta,delta), range = max(light.parameters.x,0.1f);
    if (distanceSquared >= range*range || distanceSquared < 1e-7f) return sample;
    sample.distance = sqrt(distanceSquared);
    sample.direction = delta/sample.distance;
    float noL = dot(surface.normal,sample.direction);
    if (noL <= 0 || dot(geometricNormal,sample.direction) <= 0) return sample;
    float cone = light.directionCone.w < -0.99f ? 1.0f :
        smoothstep(light.directionCone.w,light.parameters.y,dot(-sample.direction,light.directionCone.xyz));
    if (cone < 0.00001f) return sample;
    float falloff = 1.0f-pow(sample.distance/range,4.0f);
    float radius = light.positionRadius.w;
    float attenuation = cone*falloff*falloff/max(distanceSquared+radius*radius,0.01f);
    // A finite luminaire footprint prevents singular point-source GGX glints.
    // The center is shadow traced; small fixture dimensions yield crisp shadows.
    Surface filtered = surface;
    filtered.roughness = clamp(sqrt(surface.roughness*surface.roughness+radius/sample.distance*0.35f),0.065f,1.0f);
    sample.value = brdf(filtered,v,sample.direction)*light.colorPower.rgb*(light.colorPower.w*attenuation*noL);
    sample.radius = radius;
    sample.weight = max(luminance(sample.value),0.0f);
    return sample;
}

// Specialization keeps the sizable local-light reservoir out of the daylight
// kernel's register allocation. Both entry points retain the identical GPU ABI.
template <bool IsNight>
void tracePaths(texture2d<float, access::read_write> accumulation,
                constant FrameUniforms &u,
                const device SceneVertex *vertices,
                const device uint *materialIndices,
                const device SceneMaterial *materials,
                primitive_acceleration_structure scene,
                const device SceneLight *lights,
                uint2 tid) {
    if (tid.x >= u.viewport.x || tid.y >= u.viewport.y) return;
    uint rng = hashBits(tid.x + tid.y * u.viewport.x) ^ hashBits(u.viewport.w + 67u);
    float2 jitter = float2(randomFloat(rng), randomFloat(rng));
    float2 screen = (float2(tid) + jitter) / float2(u.viewport.xy) * 2.0f - 1.0f;
    ray path;
    path.origin = u.origin.xyz;
    path.direction = normalize(u.forward.xyz + screen.x * u.right.xyz - screen.y * u.up.xyz);
    path.min_distance = 0.001f;
    path.max_distance = 100000.0f;
    float3 primaryDirection = path.direction;
    float primaryDepth = 100000.0f;
    float3 radiance = 0.0f, throughput = 1.0f;
    float pixelCone = 2.0f * length(u.up.xyz) / float(u.viewport.y);
    intersector<triangle_data> closest;
    closest.assume_geometry_type(geometry_type::triangle);
    closest.force_opacity(forced_opacity::opaque);
    intersector<triangle_data> shadow;
    shadow.assume_geometry_type(geometry_type::triangle);
    shadow.force_opacity(forced_opacity::opaque);
    shadow.accept_any_intersection(true);
    uint maxBounces = uint(clamp(u.settings.y, 1.0f, 8.0f));
    ray savedReflection;
    float3 savedThroughput=0;
    bool splitPrimaryGlass=false,hasSavedReflection=false;
    uint bounce=0;
    // Split the first camera glass sheet deterministically: four-sample motion
    // must not flicker between a fully reflected and a fully transmitted image.
    // Later path vertices retain unbiased Fresnel importance sampling.
    for (uint branch=0;branch<2;++branch) {
    bool hasNonDeltaScatter=false;
    if(branch==1) {
        if(!hasSavedReflection) break;
        path=savedReflection;throughput=savedThroughput;bounce=1;
    }
    for (uint interaction=0; interaction<maxBounces+17; ++interaction) {
        auto hit = closest.intersect(path, scene);
        if (hit.type == intersection_type::none) {
            radiance += throughput * skyRadiance(path.direction, u, bounce == 0);
            break;
        }
        if (branch == 0 && interaction == 0) primaryDepth = hit.distance;
        uint vertexIndex = hit.primitive_id * 3;
        SceneVertex a = vertices[vertexIndex], b = vertices[vertexIndex + 1], c = vertices[vertexIndex + 2];
        float3 weights = float3(1.0f - hit.triangle_barycentric_coord.x - hit.triangle_barycentric_coord.y, hit.triangle_barycentric_coord);
        float3 position = a.position.xyz * weights.x + b.position.xyz * weights.y + c.position.xyz * weights.z;
        float3 geometricNormal = normalize(cross(b.position.xyz - a.position.xyz, c.position.xyz - a.position.xyz));
        if (dot(geometricNormal, path.direction) > 0.0f) geometricNormal = -geometricNormal;
        float3 n = normalize(a.normal.xyz * weights.x + b.normal.xyz * weights.y + c.normal.xyz * weights.z);
        if (dot(n, geometricNormal) < 0.0f) n = -n;
        if (dot(n, path.direction) >= -0.001f) n = geometricNormal;
        SceneMaterial material=materials[materialIndices[hit.primitive_id]];
        if (material.properties.w>0) {
            float reflectance=thinSheetReflectance(dot(geometricNormal,path.direction));
            float offset=max(0.001f,maxComponent(abs(position))*0.000008f);
            if(bounce==0 && !splitPrimaryGlass) {
                splitPrimaryGlass=true;hasSavedReflection=true;
                savedReflection=path;
                savedReflection.origin=position+geometricNormal*offset;
                savedReflection.direction=reflect(path.direction,geometricNormal);
                savedReflection.min_distance=offset*0.25f;
                savedThroughput=throughput*reflectance;
                throughput*=(1.0f-reflectance)*clamp(material.albedo.rgb,0.0f,1.0f)*saturate(material.properties.w);
                path.origin=position-geometricNormal*offset;
                path.min_distance=offset*0.25f;
                continue;
            }
            bool reflected=randomFloat(rng)<reflectance;
            if (reflected) {
                if (bounce==maxBounces) break;
                path.direction=reflect(path.direction,geometricNormal); ++bounce;
            } else {
                throughput*=clamp(material.albedo.rgb,0.0f,1.0f)*saturate(material.properties.w);
            }
            path.origin=position+geometricNormal*(reflected ? offset:-offset);
            path.min_distance=offset*0.25f;
            continue;
        }
        if (bounce == maxBounces) break;
        Surface surface = surfaceAt(material, position, n, hit.distance * pixelCone, IsNight);
        surface = regularizeSurface(surface, hasNonDeltaScatter && u.origin.w > 0.5f);
        float3 v = -path.direction;
        radiance += throughput * surface.color * surface.emission;
        float offset = max(0.0007f, maxComponent(abs(position)) * 0.000008f);
        float3 rayOrigin = position + geometricNormal * offset;
        float3 lightDirection = sunSample(normalize(u.sunDirection.xyz), max(u.settings.z, 0.001f), float2(randomFloat(rng), randomFloat(rng)));
        float noL = max(dot(surface.normal, lightDirection), 0.0f);
        if (!IsNight && noL > 0.0f && dot(geometricNormal, lightDirection) > 0.0f) {
            ray shadowRay;
            shadowRay.origin = rayOrigin;
            shadowRay.direction = lightDirection;
            shadowRay.min_distance = offset * 0.25f;
            shadowRay.max_distance = 100000.0f;
            float3 visibility=u.right.w>0.5f ? glassVisibility(shadowRay,scene,vertices,materialIndices,materials)
                : float3(shadow.intersect(shadowRay,scene).type==intersection_type::none ? 1.0f:0.0f);
            radiance += throughput * brdf(surface, v, lightDirection) * u.sunColor.xyz * noL * visibility;
        }
        if (IsNight && u.sunDirection.w > 0.0f) {
            // Evaluate the four dominant lights every sample, then one weighted
            // reservoir sample of all remaining candidates with its exact PDF.
            // This keeps most direct lighting stable in motion without dropping
            // the less important lights or tracing hundreds of shadow rays.
            DirectSample chosen[5];
            for (uint j=0;j<5;++j) { chosen[j].weight=0; chosen[j].value=0; }
            float remainderWeight=0;
            uint count=uint(u.sunDirection.w+0.5f);
            for (uint j=0;j<count;++j) {
                DirectSample candidate=evaluateLight(lights[j],surface,position,v,geometricNormal);
                if (candidate.weight<=0.000001f) continue;
                uint weakest=0;
                for (uint k=1;k<4;++k) if (chosen[k].weight<chosen[weakest].weight) weakest=k;
                if (candidate.weight>chosen[weakest].weight) {
                    DirectSample displaced=chosen[weakest];
                    chosen[weakest]=candidate; candidate=displaced;
                }
                if (candidate.weight>0) {
                    remainderWeight+=candidate.weight;
                    if (randomFloat(rng)*remainderWeight<candidate.weight) chosen[4]=candidate;
                }
            }
            if (chosen[4].weight>0) chosen[4].value*=remainderWeight/chosen[4].weight;
            for (uint j=0;j<5;++j) {
                DirectSample sample=chosen[j];
                if (sample.weight<=0) continue;
                ray visibility;
                visibility.origin=rayOrigin; visibility.direction=sample.direction;
                visibility.min_distance=offset*0.25f;
                visibility.max_distance=max(visibility.min_distance,sample.distance-sample.radius*1.8f);
                float3 transmittance=u.right.w>0.5f ? glassVisibility(visibility,scene,vertices,materialIndices,materials)
                    : float3(shadow.intersect(visibility,scene).type==intersection_type::none ? 1.0f:0.0f);
                radiance+=throughput*sample.value*transmittance;
            }
        }
        float pdf;
        float3 next = sampleBRDF(surface, v, float2(randomFloat(rng), randomFloat(rng)), randomFloat(rng), pdf);
        float cosine = dot(surface.normal, next);
        if (cosine <= 0.0f || dot(geometricNormal, next) <= 0.0f || pdf < 1e-7f) break;
        throughput *= brdf(surface, v, next) * cosine / pdf;
        if (!all(isfinite(throughput))) break;
        hasNonDeltaScatter=true;
        if (bounce >= 2) {
            float survive = clamp(maxComponent(throughput), 0.1f, 0.95f);
            if (randomFloat(rng) > survive) break;
            throughput /= survive;
        }
        path.origin = rayOrigin;
        path.direction = next;
        path.min_distance = offset * 0.25f;
        ++bounce;
    }
    }
    if (primaryDepth < 99999.0f) {
        float haze = 1.0f - exp(-primaryDepth * (IsNight ? 0.00010f : 0.00028f));
        radiance = mix(radiance, skyRadiance(primaryDirection, u, false) * 0.8f, haze);
    }
    // A high sample luminance cap suppresses rare fireflies. This is a deliberate
    // variance-versus-bias tradeoff for a responsive architectural preview.
    radiance = max(radiance, float3(0.0f));
    if (!all(isfinite(radiance))) radiance = float3(0.0f);
    radiance *= min(1.0f, 32.0f / max(luminance(radiance), 0.00001f));
    float3 mean = radiance;
    if (u.viewport.z > 0) {
        float3 previous = accumulation.read(tid).rgb;
        mean = previous + (radiance - previous) / float(u.viewport.z + 1);
    }
    // Alpha carries distance for presentation filtering, not opacity.
    accumulation.write(float4(mean, min(primaryDepth, 60000.0f)), tid);
}

kernel void pathTrace(texture2d<float, access::read_write> accumulation [[texture(0)]],
                      constant FrameUniforms &u [[buffer(0)]],
                      const device SceneVertex *vertices [[buffer(1)]],
                      const device uint *materialIndices [[buffer(2)]],
                      const device SceneMaterial *materials [[buffer(3)]],
                      primitive_acceleration_structure scene [[buffer(4)]],
                      const device SceneLight *lights [[buffer(5)]],
                      uint2 tid [[thread_position_in_grid]]) {
    tracePaths<false>(accumulation,u,vertices,materialIndices,materials,scene,lights,tid);
}

kernel void pathTraceNight(texture2d<float, access::read_write> accumulation [[texture(0)]],
                           constant FrameUniforms &u [[buffer(0)]],
                           const device SceneVertex *vertices [[buffer(1)]],
                           const device uint *materialIndices [[buffer(2)]],
                           const device SceneMaterial *materials [[buffer(3)]],
                           primitive_acceleration_structure scene [[buffer(4)]],
                           const device SceneLight *lights [[buffer(5)]],
                           uint2 tid [[thread_position_in_grid]]) {
    tracePaths<true>(accumulation,u,vertices,materialIndices,materials,scene,lights,tid);
}

struct FullscreenOut { float4 position [[position]]; float2 uv; };
vertex FullscreenOut fullscreenVertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    FullscreenOut out;
    out.position = float4(p * 2.0f - 1.0f, 0.0f, 1.0f);
    out.uv = float2(p.x, 1.0f - p.y);
    return out;
}
float3 filmic(float3 x) {
    // Narkowicz ACES fit, applied in linear light before explicit sRGB encoding.
    return saturate((x * (2.51f * x + 0.03f)) / (x * (2.43f * x + 0.59f) + 0.14f));
}
float3 encodeSRGB(float3 x) {
    return select(1.055f * pow(max(x, 0.0f), float3(1.0f / 2.4f)) - 0.055f, x * 12.92f, x <= 0.0031308f);
}
fragment float4 presentFragment(FullscreenOut in [[stage_in]],
                                texture2d<float> accumulation [[texture(0)]],
                                constant FrameUniforms &u [[buffer(0)]]) {
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 center = accumulation.sample(linearSampler, in.uv);
    float3 color = center.rgb;
    // Presentation performs only exposure, tone mapping and sRGB encoding.
    // Reconstruction belongs to Denoise.metal; --raw must remain unfiltered at
    // every sample count so matched raw/reference measurements are meaningful.
    return float4(encodeSRGB(filmic(color * max(u.settings.x, 0.0f))), 1.0f);
}
