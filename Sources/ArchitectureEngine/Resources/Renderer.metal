#include <metal_stdlib>
#include <metal_raytracing>
using namespace metal;
using namespace raytracing;

// This ABI is shared with SceneTypes.swift. Each field has 16-byte alignment.
struct SceneVertex { float4 position; float4 normal; };
struct SceneMaterial { float4 albedo; float4 properties; };
struct SceneLight { float4 positionRadius; float4 directionCone; float4 colorPower; float4 parameters; };
struct LightGridHeader { float4 originCellSize; uint4 dimensions; uint4 counts; };
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
// pbrt is Copyright(c) 1998-2020 Matt Pharr, Wenzel Jakob, and Greg Humphreys.
// The pbrt source code is licensed under the Apache License, Version 2.0.
// SPDX: Apache-2.0

// Copyright (c) 2012 Leonhard Gruenschloss (leonhard@gruenschloss.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to
// do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// These matrices are based on the following publication:
//
// S. Joe and F. Y. Kuo: "Constructing Sobol sequences with better
// two-dimensional projections", SIAM J. Sci. Comput. 30, 2635-2654 (2008).
//
// The tabulated direction numbers are available here:
// http://web.maths.unsw.edu.au/~fkuo/sobol/new-joe-kuo-6.21201

// First 16 dimensions, 32 index bits; higher path domains reuse dimensions
// with independent scrambles. Critical camera/first-two-bounce domains are unique.
constant uint pathSobolDirections[16][32] = {
    { 0x80000000, 0x40000000, 0x20000000, 0x10000000, 0x08000000, 0x04000000, 0x02000000, 0x01000000, 0x00800000, 0x00400000, 0x00200000, 0x00100000, 0x00080000, 0x00040000, 0x00020000, 0x00010000, 0x00008000, 0x00004000, 0x00002000, 0x00001000, 0x00000800, 0x00000400, 0x00000200, 0x00000100, 0x00000080, 0x00000040, 0x00000020, 0x00000010, 0x00000008, 0x00000004, 0x00000002, 0x00000001 },
    { 0x80000000, 0xc0000000, 0xa0000000, 0xf0000000, 0x88000000, 0xcc000000, 0xaa000000, 0xff000000, 0x80800000, 0xc0c00000, 0xa0a00000, 0xf0f00000, 0x88880000, 0xcccc0000, 0xaaaa0000, 0xffff0000, 0x80008000, 0xc000c000, 0xa000a000, 0xf000f000, 0x88008800, 0xcc00cc00, 0xaa00aa00, 0xff00ff00, 0x80808080, 0xc0c0c0c0, 0xa0a0a0a0, 0xf0f0f0f0, 0x88888888, 0xcccccccc, 0xaaaaaaaa, 0xffffffff },
    { 0x80000000, 0xc0000000, 0x60000000, 0x90000000, 0xe8000000, 0x5c000000, 0x8e000000, 0xc5000000, 0x68800000, 0x9cc00000, 0xee600000, 0x55900000, 0x80680000, 0xc09c0000, 0x60ee0000, 0x90550000, 0xe8808000, 0x5cc0c000, 0x8e606000, 0xc5909000, 0x6868e800, 0x9c9c5c00, 0xeeee8e00, 0x5555c500, 0x8000e880, 0xc0005cc0, 0x60008e60, 0x9000c590, 0xe8006868, 0x5c009c9c, 0x8e00eeee, 0xc5005555 },
    { 0x80000000, 0xc0000000, 0x20000000, 0x50000000, 0xf8000000, 0x74000000, 0xa2000000, 0x93000000, 0xd8800000, 0x25400000, 0x59e00000, 0xe6d00000, 0x78080000, 0xb40c0000, 0x82020000, 0xc3050000, 0x208f8000, 0x51474000, 0xfbea2000, 0x75d93000, 0xa0858800, 0x914e5400, 0xdbe79e00, 0x25db6d00, 0x58800080, 0xe54000c0, 0x79e00020, 0xb6d00050, 0x800800f8, 0xc00c0074, 0x200200a2, 0x50050093 },
    { 0x80000000, 0x40000000, 0x20000000, 0xb0000000, 0xf8000000, 0xdc000000, 0x7a000000, 0x9d000000, 0x5a800000, 0x2fc00000, 0xa1600000, 0xf0b00000, 0xda880000, 0x6fc40000, 0x81620000, 0x40bb0000, 0x22878000, 0xb3c9c000, 0xfb65a000, 0xddb2d000, 0x78022800, 0x9c0b3c00, 0x5a0fb600, 0x2d0ddb00, 0xa2878080, 0xf3c9c040, 0xdb65a020, 0x6db2d0b0, 0x800228f8, 0x400b3cdc, 0x200fb67a, 0xb00ddb9d },
    { 0x80000000, 0x40000000, 0x60000000, 0x30000000, 0xc8000000, 0x24000000, 0x56000000, 0xfb000000, 0xe0800000, 0x70400000, 0xa8600000, 0x14300000, 0x9ec80000, 0xdf240000, 0xb6d60000, 0x8bbb0000, 0x48008000, 0x64004000, 0x36006000, 0xcb003000, 0x2880c800, 0x54402400, 0xfe605600, 0xef30fb00, 0x7e48e080, 0xaf647040, 0x1eb6a860, 0x9f8b1430, 0xd6c81ec8, 0xbb249f24, 0x80d6d6d6, 0x40bbbbbb },
    { 0x80000000, 0xc0000000, 0xa0000000, 0xd0000000, 0x58000000, 0x94000000, 0x3e000000, 0xe3000000, 0xbe800000, 0x23c00000, 0x1e200000, 0xf3100000, 0x46780000, 0x67840000, 0x78460000, 0x84670000, 0xc6788000, 0xa784c000, 0xd846a000, 0x5467d000, 0x9e78d800, 0x33845400, 0xe6469e00, 0xb7673300, 0x20f86680, 0x104477c0, 0xf8668020, 0x4477c010, 0x668020f8, 0x77c01044, 0x8020f866, 0xc0104477 },
    { 0x80000000, 0x40000000, 0xa0000000, 0x50000000, 0x88000000, 0x24000000, 0x12000000, 0x2d000000, 0x76800000, 0x9e400000, 0x08200000, 0x64100000, 0xb2280000, 0x7d140000, 0xfea20000, 0xba490000, 0x1a248000, 0x491b4000, 0xc4b5a000, 0xe3739000, 0xf6800800, 0xde400400, 0xa8200a00, 0x34100500, 0x3a280880, 0x59140240, 0xeca20120, 0x974902d0, 0x6ca48768, 0xd75b49e4, 0xcc95a082, 0x87639641 },
    { 0x80000000, 0x40000000, 0xa0000000, 0x50000000, 0x28000000, 0xd4000000, 0x6a000000, 0x71000000, 0x38800000, 0x58400000, 0xea200000, 0x31100000, 0x98a80000, 0x08540000, 0xc22a0000, 0xe5250000, 0xf2b28000, 0x79484000, 0xfaa42000, 0xbd731000, 0x18a80800, 0x48540400, 0x622a0a00, 0xb5250500, 0xdab28280, 0xad484d40, 0x90a426a0, 0xcc731710, 0x20280b88, 0x10140184, 0x880a04a2, 0x84350611 },
    { 0x80000000, 0x40000000, 0xe0000000, 0xb0000000, 0x98000000, 0x94000000, 0x8a000000, 0x5b000000, 0x33800000, 0xd9c00000, 0x72200000, 0x3f100000, 0xc1b80000, 0xa6ec0000, 0x53860000, 0x29f50000, 0x0a3a8000, 0x1b2ac000, 0xd392e000, 0x69ff7000, 0xea380800, 0xab2c0400, 0x4ba60e00, 0xfde50b00, 0x60028980, 0xf006c940, 0x7834e8a0, 0x241a75b0, 0x123a8b38, 0xcf2ac99c, 0xb992e922, 0x82ff78f1 },
    { 0x80000000, 0x40000000, 0xa0000000, 0x10000000, 0x08000000, 0x6c000000, 0x9e000000, 0x23000000, 0x57800000, 0xadc00000, 0x7fa00000, 0x91d00000, 0x49880000, 0xced40000, 0x880a0000, 0x2c0f0000, 0x3e0d8000, 0x3317c000, 0x5fb06000, 0xc1f8b000, 0xe18d8800, 0xb2d7c400, 0x1e106a00, 0x6328b100, 0xf7858880, 0xbdc3c2c0, 0x77ba63e0, 0xfdf7b330, 0xd7800df8, 0xedc0081c, 0xdfa0041a, 0x81d00a2d },
    { 0x80000000, 0x40000000, 0x20000000, 0x30000000, 0x58000000, 0xac000000, 0x96000000, 0x2b000000, 0xd4800000, 0x09400000, 0xe2a00000, 0x52500000, 0x4e280000, 0xc71c0000, 0x629e0000, 0x12670000, 0x6e138000, 0xf731c000, 0x3a98a000, 0xbe449000, 0xf83b8800, 0xdc2dc400, 0xee06a200, 0xb7239300, 0x1aa80d80, 0x8e5c0ec0, 0xa03e0b60, 0x703701b0, 0x783b88c8, 0x9c2dca54, 0xce06a74a, 0x87239795 },
    { 0x80000000, 0xc0000000, 0xa0000000, 0x50000000, 0xf8000000, 0x8c000000, 0xe2000000, 0x33000000, 0x0f800000, 0x21400000, 0x95a00000, 0x5e700000, 0xd8080000, 0x1c240000, 0xba160000, 0xef370000, 0x15868000, 0x9e6fc000, 0x781b6000, 0x4c349000, 0x420e8800, 0x630bcc00, 0xf7ad6a00, 0xad739500, 0x77800780, 0x6d4004c0, 0xd7a00420, 0x3d700630, 0x2f880f78, 0xb1640ad4, 0xcdb6077a, 0x824706d7 },
    { 0x80000000, 0xc0000000, 0x60000000, 0x90000000, 0x38000000, 0xc4000000, 0x42000000, 0xa3000000, 0xf1800000, 0xaa400000, 0xfce00000, 0x85100000, 0xe0080000, 0x500c0000, 0x58060000, 0x54090000, 0x7a038000, 0x670c4000, 0xb3842000, 0x094a3000, 0x0d6f1800, 0x2f5aa400, 0x1ce7ce00, 0xd5145100, 0xb8000080, 0x040000c0, 0x22000060, 0x33000090, 0xc9800038, 0x6e4000c4, 0xbee00042, 0x261000a3 },
    { 0x80000000, 0x40000000, 0x20000000, 0xf0000000, 0xa8000000, 0x54000000, 0x9a000000, 0x9d000000, 0x1e800000, 0x5cc00000, 0x7d200000, 0x8d100000, 0x24880000, 0x71c40000, 0xeba20000, 0x75df0000, 0x6ba28000, 0x35d14000, 0x4ba3a000, 0xc5d2d000, 0xe3a16800, 0x91db8c00, 0x79aef200, 0x0cdf4100, 0x672a8080, 0x50154040, 0x1a01a020, 0xdd0dd0f0, 0x3e83e8a8, 0xaccacc54, 0xd52d529a, 0xd91d919d },
    { 0x80000000, 0xc0000000, 0x20000000, 0xd0000000, 0xd8000000, 0xc4000000, 0x46000000, 0x85000000, 0xa5800000, 0x76c00000, 0xada00000, 0x6ab00000, 0x2da80000, 0xaabc0000, 0x0daa0000, 0x7ab10000, 0xd5a78000, 0xbebd4000, 0x93a3e000, 0x3bb51000, 0x3629b800, 0x4d727c00, 0x9b836200, 0x27c4d700, 0xb629b880, 0x8d727cc0, 0xbb836220, 0xf7c4d7d0, 0x6e29b858, 0x49727c04, 0xfd836266, 0x72c4d755 }
};

uint pathOwenScramble(uint value, uint seed) {
    // Fast nested uniform scrambling, following PBRT's FastOwenScrambler.
    value = reverse_bits(value);
    value ^= value * 0x3d20adeau;
    value += seed;
    value *= (seed >> 16) | 1u;
    value ^= value * 0x05526c56u;
    value ^= value * 0x53a22864u;
    return reverse_bits(value);
}
float pathSample(uint index, uint dimension, uint pixelSeed) {
    uint value=0, bits=index;
    while (bits!=0) {
        uint bit=ctz(bits);
        value ^= pathSobolDirections[dimension&15u][bit];
        bits &= bits-1;
    }
    value=pathOwenScramble(value,hashBits(pixelSeed ^ hashBits(dimension+0x51633e2du)));
    return float(value >> 8) * (1.0f / 16777216.0f);
}
float2 pathSample2D(uint index, uint dimension, uint pixelSeed) {
    return float2(pathSample(index,dimension,pixelSeed),pathSample(index,dimension+1,pixelSeed));
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
    s.roughness = clamp(material.albedo.w, 0.02f, 1.0f);
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
    float3 geometricNormal = normalize(cross(b.position.xyz-a.position.xyz,c.position.xyz-a.position.xyz));
    if (dot(geometricNormal,primary.direction)>0.0f) geometricNormal = -geometricNormal;
    // Match the tracer's interpolated vertex normal on smooth curved geometry.
    // Using triangle face normals here breaks history/filter neighborhoods at
    // tessellation edges although the actual mirror reflection is continuous.
    float3 n = normalize(a.normal.xyz*weights.x+b.normal.xyz*weights.y+c.normal.xyz*weights.z);
    if (dot(n,geometricNormal)<0.0f) n = -n;
    if (dot(n,primary.direction)>=-0.001f) n = geometricNormal;
    uint material = materialIndices[hit.primitive_id];
    float depth=distance(p,u.origin.xyz);
    float footprint = depth*2.0f*length(u.up.xyz)/float(u.viewport.y);
    Surface s = surfaceAt(materials[material],p,n,footprint,u.sunColor.w>0.5f);
    // Emissive subpixel windows/fixtures need current coverage, not relit
    // surface history. Preserve the material ID with a half-unit guide flag.
    bool polished=s.metallic>=0.99f && s.roughness<=0.03f;
    worldPosition.write(float4(p,float(material)+(s.emission>0.0f ? 0.5f : throughGlass ? 0.75f:polished ? 0.125f:0.0f)),tid);
    normalDepth.write(float4(n,depth),tid);
    albedoRoughness.write(float4(s.color,s.roughness),tid);
}

float3 fresnelSchlick(float cosTheta, float3 f0) {
    float x = pow(1.0f - saturate(cosTheta), 5.0f);
    return f0 + (1.0f - f0) * x;
}
float ggxDistribution(float noH, float alpha) {
    // Dot products of normalized Float vectors may round just outside [0,1].
    // At polished alpha, even one ULP above one can nearly cancel the positive
    // denominator and create a false, enormous lobe peak. Clamp its domain.
    noH = saturate(noH);
    float a2 = alpha * alpha;
    // Preserve the narrow authored lobe of polished steel. The algebraically
    // equivalent (a2-1)*NoH²+1 loses significant bits near NoH=1, and a 1e-8
    // denominator floor distorted both the BRDF and PDF at low roughness.
    float d = (1.0f-noH)*(1.0f+noH) + a2*noH*noH;
    return a2 / max(PI * d * d, 1e-20f);
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
bool isSharpConductor(Surface surface) {
    // Preserve chains of authored polished metal in concave mirror sculpture.
    // These still sample finite GGX lobes; this threshold only decides whether
    // a bounce starts path regularization, never the actual reflection model.
    return surface.metallic>=0.99f && surface.roughness<=0.03f;
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
    // A pure conductor has no diffuse lobe. Giving its absent diffuse proposal
    // ten percent of the samples created avoidable noisy mirror contributions.
    float specProbability = mix(s.roughness < 0.2f ? 0.65f : 0.25f, 1.0f, s.metallic);
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
    filtered.roughness = clamp(sqrt(surface.roughness*surface.roughness+radius/sample.distance*0.35f),0.02f,1.0f);
    sample.value = brdf(filtered,v,sample.direction)*light.colorPower.rgb*(light.colorPower.w*attenuation*noL);
    sample.radius = radius;
    sample.weight = max(luminance(sample.value),0.0f);
    return sample;
}

// Specialization keeps the sizable local-light reservoir out of the daylight
// kernel's register allocation. Both entry points retain the identical GPU ABI.
template <bool IsNight, bool HasLocalLights, bool IndexedLights=false>
void tracePaths(texture2d<float, access::read_write> accumulation,
                constant FrameUniforms &u,
                const device SceneVertex *vertices,
                const device uint *materialIndices,
                const device SceneMaterial *materials,
                primitive_acceleration_structure scene,
                const device SceneLight *lights,
                constant LightGridHeader *lightGrid,
                const device uint2 *lightRanges,
                const device uint *lightIndices,
                uint2 tid) {
    if (tid.x >= u.viewport.x || tid.y >= u.viewport.y) return;
    uint pixelSeed=hashBits(tid.x + tid.y * u.viewport.x);
    uint rng = pixelSeed ^ hashBits(u.viewport.w + 67u);
    bool stratified=u.up.w>0.5f;
    float2 jitter = float2(randomFloat(rng), randomFloat(rng));
    if (stratified) jitter=pathSample2D(u.viewport.w,0,pixelSeed);
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
        uint sampleDomain=2+6*bounce+48*branch;
        float2 sunXi=float2(randomFloat(rng),randomFloat(rng));
        if (stratified) sunXi=pathSample2D(u.viewport.w,sampleDomain,pixelSeed);
        float3 lightDirection = sunSample(normalize(u.sunDirection.xyz), max(u.settings.z, 0.001f), sunXi);
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
        if (HasLocalLights && u.sunDirection.w > 0.0f) {
            // Evaluate the four dominant lights every sample, then one weighted
            // reservoir sample of all remaining candidates with its exact PDF.
            // This keeps most direct lighting stable in motion without dropping
            // the less important lights or tracing hundreds of shadow rays.
            DirectSample chosen[5];
            for (uint j=0;j<5;++j) { chosen[j].weight=0; chosen[j].value=0; }
            float remainderWeight=0;
            uint count=uint(u.sunDirection.w+0.5f);
            uint activeCount=count;
            uint lightOffset=0;
            bool indexed=false;
            if (IndexedLights && lightGrid->dimensions.w!=0) {
                // Conservative cell lists include every finite-range source
                // that can contribute here, in original order. Skipping only
                // zero-contribution lights preserves the exact reservoir RNG.
                indexed=true;
                float3 cell=floor((position-lightGrid->originCellSize.xyz)/lightGrid->originCellSize.w);
                if (all(cell>=0) && all(cell<float3(lightGrid->dimensions.xyz))) {
                    uint3 c=uint3(cell);
                    uint flat=(c.z*lightGrid->dimensions.y+c.y)*lightGrid->dimensions.x+c.x;
                    uint2 range=lightRanges[flat];
                    lightOffset=range.x;count=range.y;
                } else count=0;
            }
            for (uint j=0;j<count;++j) {
                uint index=indexed ? lightIndices[lightOffset+j]:j;
                if (index>=activeCount) continue;
                DirectSample candidate=evaluateLight(lights[index],surface,position,v,geometricNormal);
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
        float2 brdfXi=float2(randomFloat(rng),randomFloat(rng));
        float brdfChoose=randomFloat(rng);
        if (stratified) {
            brdfXi=pathSample2D(u.viewport.w,sampleDomain+2,pixelSeed);
            brdfChoose=pathSample(u.viewport.w,sampleDomain+4,pixelSeed);
        }
        float3 next = sampleBRDF(surface, v, brdfXi, brdfChoose, pdf);
        float cosine = dot(surface.normal, next);
        if (cosine <= 0.0f || dot(geometricNormal, next) <= 0.0f || pdf < 1e-7f) break;
        throughput *= brdf(surface, v, next) * cosine / pdf;
        if (!all(isfinite(throughput))) break;
        hasNonDeltaScatter=hasNonDeltaScatter || !isSharpConductor(surface);
        if (bounce >= 2) {
            float survive = clamp(maxComponent(throughput), 0.1f, 0.95f);
            float roulette=randomFloat(rng);
            if (stratified) roulette=pathSample(u.viewport.w,sampleDomain+5,pixelSeed);
            if (roulette > survive) break;
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
    tracePaths<false,false>(accumulation,u,vertices,materialIndices,materials,scene,lights,nullptr,nullptr,nullptr,tid);
}

kernel void pathTraceDayInteriors(texture2d<float, access::read_write> accumulation [[texture(0)]],
                           constant FrameUniforms &u [[buffer(0)]],
                           const device SceneVertex *vertices [[buffer(1)]],
                           const device uint *materialIndices [[buffer(2)]],
                           const device SceneMaterial *materials [[buffer(3)]],
                           primitive_acceleration_structure scene [[buffer(4)]],
                           const device SceneLight *lights [[buffer(5)]],
                           uint2 tid [[thread_position_in_grid]]) {
    tracePaths<false,true>(accumulation,u,vertices,materialIndices,materials,scene,lights,nullptr,nullptr,nullptr,tid);
}

kernel void pathTraceNight(texture2d<float, access::read_write> accumulation [[texture(0)]],
                           constant FrameUniforms &u [[buffer(0)]],
                           const device SceneVertex *vertices [[buffer(1)]],
                           const device uint *materialIndices [[buffer(2)]],
                           const device SceneMaterial *materials [[buffer(3)]],
                           primitive_acceleration_structure scene [[buffer(4)]],
                           const device SceneLight *lights [[buffer(5)]],
                           uint2 tid [[thread_position_in_grid]]) {
    tracePaths<true,true>(accumulation,u,vertices,materialIndices,materials,scene,lights,nullptr,nullptr,nullptr,tid);
}

kernel void pathTraceNightIndexed(texture2d<float, access::read_write> accumulation [[texture(0)]],
                           constant FrameUniforms &u [[buffer(0)]],
                           const device SceneVertex *vertices [[buffer(1)]],
                           const device uint *materialIndices [[buffer(2)]],
                           const device SceneMaterial *materials [[buffer(3)]],
                           primitive_acceleration_structure scene [[buffer(4)]],
                           const device SceneLight *lights [[buffer(5)]],
                           constant LightGridHeader &grid [[buffer(6)]],
                           const device uint2 *ranges [[buffer(7)]],
                           const device uint *indices [[buffer(8)]],
                           uint2 tid [[thread_position_in_grid]]) {
    tracePaths<true,true,true>(accumulation,u,vertices,materialIndices,materials,scene,lights,&grid,ranges,indices,tid);
}

kernel void pathTraceDayInteriorsIndexed(texture2d<float, access::read_write> accumulation [[texture(0)]],
                           constant FrameUniforms &u [[buffer(0)]],
                           const device SceneVertex *vertices [[buffer(1)]],
                           const device uint *materialIndices [[buffer(2)]],
                           const device SceneMaterial *materials [[buffer(3)]],
                           primitive_acceleration_structure scene [[buffer(4)]],
                           const device SceneLight *lights [[buffer(5)]],
                           constant LightGridHeader &grid [[buffer(6)]],
                           const device uint2 *ranges [[buffer(7)]],
                           const device uint *indices [[buffer(8)]],
                           uint2 tid [[thread_position_in_grid]]) {
    tracePaths<false,true,true>(accumulation,u,vertices,materialIndices,materials,scene,lights,&grid,ranges,indices,tid);
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
