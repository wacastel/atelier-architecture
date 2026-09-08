#include <metal_stdlib>
using namespace metal;

// Independent of FrameUniforms; shared verbatim with the Swift renderer and
// scripts/validate-denoiser.swift. Seven 16-byte vectors = 112 bytes.
struct TemporalUniforms {
    float4 previousOrigin, previousRight, previousUp, previousForward;
    float4 currentOrigin;
    uint4 sizeFlags; // width, height, history valid, camera moving
    float4 settings; // maximum history frames, current SPP, a-trous step, current pixel cone
};

float reconstructionLuminance(float3 color) {
    return dot(color, float3(0.2126f, 0.7152f, 0.0722f));
}
float3 finiteRadiance(float3 color) {
    return all(isfinite(color)) ? max(color, 0.0f) : float3(0.0f);
}
bool validPixel(int2 p, uint2 size) {
    return all(p >= int2(0)) && all(p < int2(size));
}
bool requiresCurrentCoverage(float materialGuide) {
    // Integer IDs describe reflecting surfaces; +0.5 identifies an emitter,
    // +0.75 an opaque surface viewed through glass (no shared reflection motion).
    // +0.875 marks moving geometry or locally affected lighting/reflections.
    // +0.25 marks stationary rough diffuse surfaces relit by an animated source:
    // no historical lighting, but current-frame spatial filtering remains safe.
    // Surface-lighting reconstruction cannot reliably track subpixel emitter
    // coverage. Preserve current coverage of sky and visible lights.
    return materialGuide < 0.0f || fract(materialGuide) > 0.25f || fract(materialGuide) == 0.25f;
}
float pixelFootprint(float depth, constant TemporalUniforms &u) {
    return max(0.0005f, 2.0f * length(u.previousUp.xyz) * depth / float(u.sizeFlags.y));
}
float currentPixelFootprint(float depth, constant TemporalUniforms &u) {
    // Current geometry filtering must follow a changing FOV during a zoom,
    // while history validation continues to use the previous camera's cone.
    return u.settings.w > 0.0f ? max(0.0005f, u.settings.w * depth) : pixelFootprint(depth, u);
}

float surfaceColorWeight(float4 a, float4 b) {
    float3 difference = (a.rgb - b.rgb) / max(a.rgb + b.rgb, float3(0.05f));
    return exp(-64.0f * dot(difference, difference) - 10.0f * abs(a.w - b.w));
}

// Material and tangent-plane tests distinguish a rivet from its backing plate,
// as well as a narrow piece of lattice from the sky behind it. A depth-only
// bilateral filter cannot distinguish the former reliably during camera pans.
float spatialGeometryWeight(float4 centerWorld, float4 centerNormal,
                            float4 otherWorld, float4 otherNormal,
                            float footprint, float step) {
    if (abs(centerWorld.w - otherWorld.w) > 0.1f) return 0.0f;
    if (centerWorld.w < 0.0f) return 1.0f;
    float agreement = max(dot(centerNormal.xyz, otherNormal.xyz), 0.0f);
    if (agreement < 0.8f) return 0.0f;
    float3 delta = otherWorld.xyz - centerWorld.xyz;
    float planeDistance = max(abs(dot(delta, centerNormal.xyz)), abs(dot(delta, otherNormal.xyz)));
    if (planeDistance > max(0.001f, footprint * 0.35f)) return 0.0f;
    float planeTolerance = max(0.0004f, footprint * 0.08f);
    return pow(agreement, 64.0f) * exp(-planeDistance / planeTolerance);
}

kernel void temporalResolve(
    texture2d<float, access::read> currentRadiance [[texture(0)]],
    texture2d<float, access::read> currentWorld [[texture(1)]],
    texture2d<float, access::read> currentNormalDepth [[texture(2)]],
    texture2d<float, access::read> currentAlbedo [[texture(3)]],
    texture2d<float, access::read> previousHistory [[texture(4)]],
    texture2d<float, access::read> previousWorld [[texture(5)]],
    texture2d<float, access::read> previousNormalDepth [[texture(6)]],
    texture2d<float, access::write> outputHistory [[texture(7)]],
    constant TemporalUniforms &u [[buffer(0)]],
    uint2 tid [[thread_position_in_grid]]) {
    if (any(tid >= u.sizeFlags.xy)) return;
    float3 current = finiteRadiance(currentRadiance.read(tid).rgb);
    float4 world = currentWorld.read(tid);
    float4 normalDepth = currentNormalDepth.read(tid);
    float4 albedo = currentAlbedo.read(tid);
    // A pixel-center ray can miss thin ironwork while jittered radiance samples
    // still include its bright silhouette. Treating that mixed coverage as an
    // infinite-distance sky surface leaves gold trails during a camera orbit.
    // The analytic sky requires no reconstruction; raw stationary accumulation
    // already converges its subpixel silhouette coverage without stale history.
    if (u.sizeFlags.z == 0 || requiresCurrentCoverage(world.w)) {
        outputHistory.write(float4(current, 1.0f), tid);
        return;
    }

    // Beyond quarter-metre pixel footprints, thin ironwork, windows and their stone
    // surrounds are unresolved coverage, rather than stable surface samples.
    // At night their contrast makes history unreliable. Keep current spatial
    // reconstruction while preventing bright samples from lingering on stone.
    if (u.currentOrigin.w>0.5f && currentPixelFootprint(normalDepth.w,u)>0.25f) {
        outputHistory.write(float4(current,1.0f),tid);
        return;
    }

    float3 relative = world.xyz - u.previousOrigin.xyz;
    float viewDepth = dot(relative, normalize(u.previousForward.xyz));
    if (viewDepth <= 0.0001f) {
        outputHistory.write(float4(current, 1.0f), tid);
        return;
    }
    float2 screen = float2(dot(relative, u.previousRight.xyz) / max(dot(u.previousRight.xyz, u.previousRight.xyz), 1e-8f),
                          -dot(relative, u.previousUp.xyz) / max(dot(u.previousUp.xyz, u.previousUp.xyz), 1e-8f)) / viewDepth;
    float2 pixel = (screen * 0.5f + 0.5f) * float2(u.sizeFlags.xy) - 0.5f;
    int2 base = int2(floor(pixel));
    float2 fraction = fract(pixel);
    float footprint = pixelFootprint(length(relative), u);
    float3 historical = 0.0f;
    float historyCount = 0.0f, accepted = 0.0f;
    for (int y = 0; y <= 1; ++y) for (int x = 0; x <= 1; ++x) {
        int2 q = base + int2(x, y);
        if (!validPixel(q, u.sizeFlags.xy)) continue;
        float weight = (x == 0 ? 1.0f - fraction.x : fraction.x) *
                       (y == 0 ? 1.0f - fraction.y : fraction.y);
        if (weight <= 0.00001f) continue;
        float4 oldWorld = previousWorld.read(uint2(q));
        float4 oldNormalDepth = previousNormalDepth.read(uint2(q));
        if (abs(world.w - oldWorld.w) > 0.1f) continue;
        if (dot(normalDepth.xyz, oldNormalDepth.xyz) < 0.92f) continue;
        // The world-distance bound stops a newly revealed object from
        // borrowing a similarly coloured, similarly oriented old surface.
        if (distance(world.xyz, oldWorld.xyz) > max(0.002f, footprint * 1.75f)) continue;
        float planeDistance = abs(dot(oldWorld.xyz - world.xyz, normalDepth.xyz));
        if (planeDistance > max(0.0008f, footprint * 0.28f)) continue;
        if (abs(oldNormalDepth.w - length(relative)) > max(0.003f, footprint * 2.0f)) continue;
        float4 history = previousHistory.read(uint2(q));
        if (!all(isfinite(history)) || history.w < 1.0f) continue;
        historical += max(history.rgb, 0.0f) * weight;
        historyCount += history.w * weight;
        accepted += weight;
    }
    if (accepted < 0.05f) {
        outputHistory.write(float4(current, 1.0f), tid);
        return;
    }
    historical /= accepted;
    historyCount /= accepted;

    // Geometry-aware current-frame moments constrain stale illumination without
    // allowing the sky or a backing plate to clip a fine foreground member.
    float moment1 = 0.0f, moment2 = 0.0f, momentWeight = 0.0f;
    float currentFootprint = currentPixelFootprint(normalDepth.w, u);
    for (int y = -1; y <= 1; ++y) for (int x = -1; x <= 1; ++x) {
        int2 q = int2(tid) + int2(x, y);
        if (!validPixel(q, u.sizeFlags.xy)) continue;
        float w = spatialGeometryWeight(world, normalDepth, currentWorld.read(uint2(q)),
                                       currentNormalDepth.read(uint2(q)), currentFootprint, 1.0f);
        // Lit and unlit windows can share a material and a facade plane. A
        // neighboring lit room must not widen the history clamp for a dark room.
        w *= surfaceColorWeight(albedo, currentAlbedo.read(uint2(q)));
        float luma = reconstructionLuminance(finiteRadiance(currentRadiance.read(uint2(q)).rgb));
        moment1 += luma * w;
        moment2 += luma * luma * w;
        momentWeight += w;
    }
    float mean = moment1 / max(momentWeight, 0.0001f);
    float variance = max(0.0f, moment2 / max(momentWeight, 0.0001f) - mean * mean);
    // Keep the absolute tolerance below visible night radiance. A daylight-sized
    // floor can retain a bright foreground coverage sample over a distant dark
    // building even after that foreground has left the pixel entirely.
    float deviation = max(sqrt(variance), 0.0005f + 0.08f * mean);
    float oldLuma = reconstructionLuminance(historical);
    float upperLuma = mean + 2.75f * deviation;
    if (oldLuma > 2.0f * upperLuma && reconstructionLuminance(current) <= upperLuma) {
        // A grossly incompatible highlight is a coverage/visibility change,
        // not useful lighting history. Reset instead of leaving a clipped,
        // coloured remainder that could trail over near-black city geometry.
        outputHistory.write(float4(current, 1.0f), tid);
        return;
    }
    float clippedLuma = clamp(oldLuma, max(0.0f, mean - 2.75f * deviation), upperLuma);
    historical *= clippedLuma / max(oldLuma, 0.00001f);

    float maximumHistory = clamp(u.settings.x, 1.0f, 64.0f);
    if (u.sizeFlags.w != 0) {
        // A camera rotation reprojects the same surface/view direction exactly;
        // a slow translation changes it much less than a GGX lobe's angular
        // width. Do not discard that useful lighting history merely because
        // the camera moved. Fast glossy changes keep the two-frame safeguard.
        float3 currentView=normalize(u.currentOrigin.xyz-world.xyz);
        float3 previousView=normalize(u.previousOrigin.xyz-world.xyz);
        float angularChange=length(currentView-previousView);
        float angularBudget=0.1f*max(albedo.w*albedo.w,0.0004f);
        float slowMotionLimit=clamp(angularBudget/max(angularChange,0.000001f),2.0f,16.0f);
        float roughnessLimit=mix(2.0f,maximumHistory,smoothstep(0.08f,0.42f,albedo.w));
        maximumHistory=min(maximumHistory,max(roughnessLimit,slowMotionLimit));
    }
    // Progressive stationary input already contains many samples; adding long
    // correlated history would only delay its convergence.
    if (u.sizeFlags.w == 0 && u.settings.y > 16.0f) maximumHistory = min(maximumHistory, 4.0f);
    float count = min(historyCount + 1.0f, maximumHistory);
    float alpha = 1.0f / max(count, 1.0f);
    outputHistory.write(float4(finiteRadiance(mix(historical,current,alpha)),count),tid);
}

kernel void spatialFilter(
    texture2d<float, access::read> inputHDR [[texture(0)]],
    texture2d<float, access::read> currentWorld [[texture(1)]],
    texture2d<float, access::read> currentNormalDepth [[texture(2)]],
    texture2d<float, access::read> currentAlbedo [[texture(3)]],
    texture2d<float, access::write> outputHDR [[texture(4)]],
    constant TemporalUniforms &u [[buffer(0)]],
    uint2 tid [[thread_position_in_grid]]) {
    if (any(tid >= u.sizeFlags.xy)) return;
    float3 center = finiteRadiance(inputHDR.read(tid).rgb);
    float4 world = currentWorld.read(tid);
    float4 normalDepth = currentNormalDepth.read(tid);
    float4 albedo = currentAlbedo.read(tid);
    // Avoid spreading partially covered bright silhouette pixels into clear
    // analytic sky. Surface reconstruction remains fully edge-aware below.
    // The new +0.25 diffuse-lighting tag deliberately reaches this filtering
    // path; +0.875 screen/reflection/traffic coverage remains untouched.
    if (world.w<0 || (fract(world.w)>0.25f && fract(world.w)<0.7f) || fract(world.w)>0.8f) {
        outputHDR.write(float4(center, normalDepth.w), tid);
        return;
    }
    if (fract(world.w)>0.1f && fract(world.w)<0.15f) {
        // Polished-metal reflections contain real scene edges that are absent
        // from primary albedo/normal guides. Surface-only spatial filtering
        // erases those edges; keep their angularly validated temporal result.
        outputHDR.write(float4(center,normalDepth.w),tid);
        return;
    }
    // A center ray can hit pale stone while jittered radiance includes its
    // narrow dark joint. Rejecting only different-material neighbors erases
    // that legitimate fractional coverage asymmetrically. Preserve the local
    // result on BOTH sides of a contrasting material boundary; stable regions
    // farther from the edge still receive the full spatial filter.
    for (int y=-1; y<=1; ++y) for (int x=-1; x<=1; ++x) {
        int2 q=int2(tid)+int2(x,y);
        if (!validPixel(q,u.sizeFlags.xy)) continue;
        float4 otherWorld=currentWorld.read(uint2(q));
        if (otherWorld.w<0 || abs(floor(otherWorld.w)-floor(world.w))<0.5f) continue;
        if (surfaceColorWeight(albedo,currentAlbedo.read(uint2(q)))<0.01f) {
            outputHDR.write(float4(center,normalDepth.w),tid);
            return;
        }
    }
    float footprint = currentPixelFootprint(normalDepth.w, u);
    if (u.currentOrigin.w > 0.5f && footprint > 0.25f) {
        // At coarse night coverage, the center ray can hit a dark mullion while
        // jittered rays legitimately include its luminous neighboring window.
        // Filtering only the dark-center pixels (emitters bypass above) erodes
        // that coverage asymmetrically and makes the window flicker during pans.
        // Preserve the complete current neighborhood around visible emitters;
        // smooth distant water/roofs still benefit from spatial reconstruction.
        for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {
            int2 q = int2(tid) + int2(x, y);
            if (!validPixel(q, u.sizeFlags.xy)) continue;
            float material = currentWorld.read(uint2(q)).w;
            float flag = fract(material);
            if (material >= 0.0f && flag > 0.25f && flag < 0.7f) {
                outputHDR.write(float4(center, normalDepth.w), tid);
                return;
            }
        }
    }
    int step = int(clamp(u.settings.z, 1.0f, 4.0f));
    float centerLuma = reconstructionLuminance(center);
    float sumLuma = 0.0f, sumLuma2 = 0.0f, totalMoment = 0.0f;
    for (int y = -1; y <= 1; ++y) for (int x = -1; x <= 1; ++x) {
        int2 q = int2(tid) + int2(x, y);
        if (!validPixel(q, u.sizeFlags.xy)) continue;
        float weight = spatialGeometryWeight(world, normalDepth, currentWorld.read(uint2(q)),
                                            currentNormalDepth.read(uint2(q)), footprint, 1.0f);
        float luma = reconstructionLuminance(finiteRadiance(inputHDR.read(uint2(q)).rgb));
        sumLuma += weight * luma;
        sumLuma2 += weight * luma * luma;
        totalMoment += weight;
    }
    float mean = sumLuma / max(totalMoment, 0.00001f);
    float variance = max(0.0f, sumLuma2 / max(totalMoment, 0.00001f) - mean * mean);
    // A daylight-sized absolute tolerance treats distinct dim reflections and
    // fractional window coverage as interchangeable. Match the temporal clamp's
    // low-radiance floor at night while retaining measured variance and relative
    // luminance terms, so ordinary dim-surface sampling noise is still reduced.
    float absoluteTolerance = u.currentOrigin.w > 0.5f ? 0.0005f : 0.03f;
    float lumaScale = 3.0f * sqrt(variance) + absoluteTolerance + 0.04f * centerLuma;
    constexpr float wavelet[5] = { 1.0f, 4.0f, 6.0f, 4.0f, 1.0f };
    float3 result = 0.0f;
    float total = 0.0f;
    for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {
        int2 q = int2(tid) + int2(x, y) * step;
        if (!validPixel(q, u.sizeFlags.xy)) continue;
        float weight = spatialGeometryWeight(world, normalDepth, currentWorld.read(uint2(q)),
                                            currentNormalDepth.read(uint2(q)), footprint, float(step));
        if (weight < 0.0001f) continue;
        float4 otherAlbedo = currentAlbedo.read(uint2(q));
        weight *= surfaceColorWeight(albedo, otherAlbedo);
        float3 other = finiteRadiance(inputHDR.read(uint2(q)).rgb);
        weight *= exp(-abs(reconstructionLuminance(other) - centerLuma) / lumaScale);
        weight *= wavelet[x + 2] * wavelet[y + 2];
        result += other * weight;
        total += weight;
    }
    // Trust genuinely accumulated samples sooner as sampling error falls.
    // The eight-sample confidence scale limits bias on converging shadows and
    // subpixel coverage; stronger blur was erasing detail at higher SPP.
    // Restrict wide passes for shiny surfaces as before.
    float strength = clamp(8.0f / (max(u.settings.y, 1.0f) + 8.0f), 0.0f, 0.92f);
    if (step > 1 && world.w >= 0.0f) strength *= smoothstep(0.08f, 0.3f, albedo.w);
    float3 filtered = total > 0.0f ? mix(center, result / total, strength) : center;
    outputHDR.write(float4(finiteRadiance(filtered), normalDepth.w), tid);
}
