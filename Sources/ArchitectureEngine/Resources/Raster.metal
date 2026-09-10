// Appended after Renderer.metal so rasterization shares the authored procedural
// materials, atmosphere, BRDF and color management. No raster entry point calls
// any ray/intersection function or binds an acceleration structure.
struct RasterOut {
    float4 position [[position]];
    float3 world;
    float3 normal;
    uint material [[flat]];
};
vertex RasterOut rasterVertex(uint id [[vertex_id]],
                              constant FrameUniforms &u [[buffer(0)]],
                              const device SceneVertex *vertices [[buffer(1)]],
                              const device uint *materials [[buffer(2)]],
                              constant uint4 &draw [[buffer(4)]],
                              const device uint *owners [[buffer(5)]],
                              const device float4x4 *transforms [[buffer(6)]]) {
    // 64-bit address arithmetic also covers the unified city buffer beyond 4GiB.
    SceneVertex sourceVertex=vertices[ulong(id)];
    float3 p=sourceVertex.position.xyz,n=sourceVertex.normal.xyz;
    if(draw.x!=0) {
        float4x4 model=transforms[owners[id]];
        p=(model*float4(p,1)).xyz;n=(model*float4(n,0)).xyz;
    }
    float3 q=p-u.origin.xyz;
    float z=dot(q,u.forward.xyz);
    RasterOut out;
    // Infinite reversed-Z projection: near=4cm, far=infinity. Unlike a finite
    // kilometre-scale far plane this keeps facade/road depth precision nearby.
    out.position=float4(dot(q,u.right.xyz)/dot(u.right.xyz,u.right.xyz),
                        dot(q,u.up.xyz)/dot(u.up.xyz,u.up.xyz),0.04f,z);
    out.world=p;out.normal=n;
    out.material=materials[ulong(id)/3ul+(draw.x!=0 ? ulong(draw.y):0ul)];
    return out;
}
fragment float4 rasterSkyFragment(FullscreenOut in [[stage_in]],constant FrameUniforms &u [[buffer(0)]]) {
    float2 screen=in.uv*2-1;
    float3 direction=normalize(u.forward.xyz+screen.x*u.right.xyz-screen.y*u.up.xyz);
    return float4(u.sunColor.w>0.5f ? skyRadiance(direction,u,true):daylightCameraBackground(direction,u),60000);
}
float4 rasterShade(RasterOut in,bool front,constant FrameUniforms &u,
                   SceneMaterial material,const device SceneLight *lights,
                   constant LightGridHeader &grid,const device uint2 *ranges,const device uint *indices) {
    float3 v=normalize(u.origin.xyz-in.world),n=normalize(in.normal);
    if(dot(n,v)<0)n=-n;
    float footprint=max(length(dfdx(in.world)),length(dfdy(in.world)));
    Surface s=surfaceAt(material,in.world,n,footprint,u.sunColor.w>0.5f,u.animation.x,u.animation.z<1.5f);
    // Analytic environment reflections preserve polished material character;
    // raster mode does not promise traced local reflections/refraction or GI.
    float3 reflection=reflect(-v,s.normal);
    float3 f=fresnelSchlick(max(dot(s.normal,v),0.0f),mix(float3(s.dielectricF0),s.color,s.metallic));
    float3 environment=mix(skyRadiance(reflection,u,false),skyRadiance(s.normal,u,false),s.roughness*s.roughness);
    float3 ambient=skyRadiance(s.normal,u,false)*(u.sunColor.w>0.5f ? 0.8f:0.42f);
    float3 radiance=s.color*s.emission+(1-f)*(1-s.metallic)*s.color*ambient+f*environment;
    Surface sunSurface=s;sunSurface.roughness=max(sunSurface.roughness,0.12f);
    float noL=max(dot(s.normal,u.sunDirection.xyz),0.0f);
    radiance+=brdf(sunSurface,v,u.sunDirection.xyz)*u.sunColor.xyz*noL;
    uint first=0,count=uint(u.sunDirection.w);
    if(count>0 && grid.dimensions.w!=0) {
        float3 cell=floor((in.world-grid.originCellSize.xyz)/grid.originCellSize.w);
        count=0;
        if(all(cell>=0) && all(cell<float3(grid.dimensions.xyz))) {
            uint3 q=uint3(cell);uint c=(q.z*grid.dimensions.y+q.y)*grid.dimensions.x+q.x;
            uint2 range=ranges[c];first=range.x;count=range.y;
        }
    }
    // Fixed deterministic budget: finite-range local lights are evaluated
    // without stochastic reservoirs, visibility rays or flickering frame seeds.
    uint selected=min(count,64u);
    for(uint j=0;j<selected;++j) {
        uint offset=count<=64u ? j:uint((ulong(j)*ulong(count))/64ul);
        uint index=grid.dimensions.w!=0 ? indices[first+offset]:offset;
        radiance+=evaluateLight(lights[index],s,in.world,v,n).value;
    }
    float distance=length(in.world-u.origin.xyz);
    if(u.sunColor.w<0.5f || u.animation.z>0.5f || u.animation.w>0) {
        float density=u.animation.w>0 ? u.animation.w:0.00018f;
        float haze=1-exp(-distance*density);
        float3 scattering=u.sunColor.w>0.5f ? skyRadiance(-v,u,false):daylightAerialPerspective(-v,u);
        radiance=mix(radiance,scattering*0.8f,haze);
    }
    // Thin-sheet glass is blended after opaque depth; transmission tint is
    // approximate and does not refract or reflect the local scene.
    float transmission=saturate(material.properties.w);
    float alpha=transmission>0 ? clamp(1-transmission+thinSheetReflectance(dot(n,v)),0.06f,0.85f):1;
    return float4(max(radiance,float3(0)),alpha);
}
fragment float4 rasterOpaqueFragment(RasterOut in [[stage_in]],bool front [[front_facing]],
                                     constant FrameUniforms &u [[buffer(0)]],
                                     const device SceneMaterial *materials [[buffer(3)]],
                                     const device SceneLight *lights [[buffer(5)]],
                                     constant LightGridHeader &grid [[buffer(6)]],
                                     const device uint2 *ranges [[buffer(7)]],const device uint *indices [[buffer(8)]]) {
    SceneMaterial material=materials[in.material];
    if(material.properties.w>0)discard_fragment();
    float4 shaded=rasterShade(in,front,u,material,lights,grid,ranges,indices);
    // The opaque distance supports selection presentation without a ray pass.
    shaded.w=min(length(in.world-u.origin.xyz),60000.0f);
    return shaded;
}
fragment float4 rasterGlassFragment(RasterOut in [[stage_in]],bool front [[front_facing]],
                                    constant FrameUniforms &u [[buffer(0)]],
                                    const device SceneMaterial *materials [[buffer(3)]],
                                    const device SceneLight *lights [[buffer(5)]],
                                    constant LightGridHeader &grid [[buffer(6)]],
                                    const device uint2 *ranges [[buffer(7)]],const device uint *indices [[buffer(8)]]) {
    SceneMaterial material=materials[in.material];
    if(material.properties.w<=0)discard_fragment();
    return rasterShade(in,front,u,material,lights,grid,ranges,indices);
}
