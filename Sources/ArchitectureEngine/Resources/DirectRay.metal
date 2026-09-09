// Deterministic direct illumination with a bounded Whitted-style ray tree.
// Shared scene/material/lighting routines come from Renderer.metal. There is
// no random generator, progressive accumulation or temporal lighting history.
// Diffuse indirect light and rough environment reflection are approximations.

template<bool HasTraffic, typename Scene>
float3 directLighting(Surface s, float3 p, float3 geometricNormal, float3 view,
                      Scene scene, uint staticTriangles,
                      const device SceneVertex *vertices, const device uint *materialIndices,
                      const device SceneMaterial *materials, constant FrameUniforms &u,
                      const device SceneLight *lights, constant LightGridHeader &grid,
                      const device uint2 *ranges, const device uint *indices,
                      float reflectionMix, constant uint4 *traffic,
                      constant LightGridHeader *trafficGrid, const device uint2 *trafficRanges,
                      const device uint *trafficIndices, const device SceneLight *trafficLights) {
    bool night=u.sunColor.w>0.5f;
    float3 reflected=reflect(-view,s.normal);
    float3 fresnel=fresnelSchlick(max(dot(s.normal,view),0.0f),mix(float3(s.dielectricF0),s.color,s.metallic));
    float3 ambient=skyRadiance(s.normal,u,false)*(night ? 0.65f:0.42f);
    float3 environment=mix(skyRadiance(reflected,u,false),skyRadiance(s.normal,u,false),s.roughness*s.roughness);
    float3 result=s.color*s.emission+(1-fresnel)*(1-s.metallic)*s.color*ambient
        +fresnel*environment*(1-reflectionMix);
    float epsilon=max(0.001f,maxComponent(abs(p))*0.000008f);
    ray shadow;
    shadow.origin=p+geometricNormal*epsilon;shadow.min_distance=epsilon*0.25f;
    float noL=max(dot(s.normal,u.sunDirection.xyz),0.0f);
    if(noL>0 && dot(geometricNormal,u.sunDirection.xyz)>0 && maxComponent(u.sunColor.xyz)>0.00001f) {
        shadow.direction=normalize(u.sunDirection.xyz);shadow.max_distance=100000;
        Surface filtered=s;filtered.roughness=max(filtered.roughness,0.10f);
        result+=brdf(filtered,view,shadow.direction)*u.sunColor.xyz*noL
            *glassVisibility(shadow,scene,vertices,materialIndices,materials,staticTriangles);
    }
    uint first=0,count=uint(u.sunDirection.w);
    if(grid.dimensions.w!=0) {
        float3 cell=floor((p-grid.originCellSize.xyz)/grid.originCellSize.w);
        count=0;
        if(all(cell>=0) && all(cell<float3(grid.dimensions.xyz))) {
            uint3 q=uint3(cell);uint index=(q.z*grid.dimensions.y+q.y)*grid.dimensions.x+q.x;
            uint2 range=ranges[index];first=range.x;count=range.y;
        }
    }
    // All locally supported lights contribute. Four strongest lights receive
    // geometric visibility; the fifth contribution fades the shadow correction
    // at rank crossings instead of letting a shadow suddenly appear/disappear.
    DirectSample strongest[5];
    for(uint i=0;i<5;++i) {strongest[i].weight=0;strongest[i].value=0;}
    float3 local=0;
    uint dynamicFirst=0,dynamicCount=0;
    bool dynamicIndexed=false;
    if(HasTraffic && night) {
        dynamicCount=traffic->z;
        dynamicIndexed=trafficGrid->dimensions.w!=0;
        if(dynamicIndexed) {
            float3 cell=floor((p-trafficGrid->originCellSize.xyz)/trafficGrid->originCellSize.w);
            dynamicCount=0;
            if(all(cell>=0) && all(cell<float3(trafficGrid->dimensions.xyz))) {
                uint3 q=uint3(cell);uint index=(q.z*trafficGrid->dimensions.y+q.y)*trafficGrid->dimensions.x+q.x;
                uint2 range=trafficRanges[index];dynamicFirst=range.x;dynamicCount=range.y;
            }
        }
    }
    for(uint i=0;i<count+dynamicCount;++i) {
        DirectSample candidate;
        if(i<count) {
            uint index=grid.dimensions.w!=0 ? indices[first+i]:i;
            candidate=evaluateLight(lights[index],s,p,view,geometricNormal);
        } else {
            uint index=dynamicIndexed ? trafficIndices[dynamicFirst+i-count]:i-count;
            candidate=evaluateLight(trafficLights[index],s,p,view,geometricNormal);
        }
        if(candidate.weight<=0)continue;
        local+=candidate.value;
        for(uint rank=0;rank<5;++rank) {
            if(candidate.weight>strongest[rank].weight) {
                DirectSample previous=strongest[rank];strongest[rank]=candidate;candidate=previous;
            }
        }
    }
    float threshold=strongest[4].weight;
    for(uint i=0;i<4;++i) {
        DirectSample selected=strongest[i];
        if(selected.weight<=0)continue;
        shadow.direction=selected.direction;
        shadow.max_distance=max(epsilon,selected.distance-selected.radius*0.6f-epsilon*2);
        float3 visibility=glassVisibility(shadow,scene,vertices,materialIndices,materials,staticTriangles);
        float weight=threshold>0 ? smoothstep(threshold,threshold*1.75f,selected.weight):1.0f;
        local-=selected.value*(1-visibility)*weight;
    }
    return max(result+local,0.0f);
}

template<bool HasTraffic, typename Scene>
void traceDirect(texture2d<float,access::write> output, constant FrameUniforms &u,
                 const device SceneVertex *vertices,const device uint *materialIndices,
                 const device SceneMaterial *materials, Scene scene,
                 const device SceneLight *lights,constant LightGridHeader &grid,
                 const device uint2 *ranges,const device uint *indices,uint staticTriangles,uint2 tid,
                 constant uint4 *traffic=nullptr, constant LightGridHeader *trafficGrid=nullptr,
                 const device uint2 *trafficRanges=nullptr,const device uint *trafficIndices=nullptr,
                 const device SceneLight *trafficLights=nullptr) {
    if(any(tid>=u.viewport.xy))return;
    float2 screen=(float2(tid)+0.5f)/float2(u.viewport.xy)*2-1;
    float3 directions[3],origins[3],weights[3];
    directions[0]=normalize(u.forward.xyz+screen.x*u.right.xyz-screen.y*u.up.xyz);
    origins[0]=u.origin.xyz;weights[0]=1;
    uint rays=1;
    float3 color=0;
    float primaryDepth=60000;
    bool night=u.sunColor.w>0.5f;
    float cone=2*length(u.up.xyz)/float(u.viewport.y);
    for(uint branch=0;branch<rays && branch<3;++branch) {
        ray r;r.origin=origins[branch];r.direction=directions[branch];r.min_distance=0.001f;r.max_distance=100000;
        float3 throughput=weights[branch];
        for(uint layer=0;layer<12;++layer) {
            auto hit=sceneIntersection(r,scene,false,staticTriangles);
            if(hit.type==intersection_type::none) {
                float3 sky=branch==0 && !night ? daylightCameraBackground(r.direction,u):skyRadiance(r.direction,u,branch==0);
                color+=throughput*sky;break;
            }
            if(branch==0 && layer==0)primaryDepth=min(hit.distance,60000.0f);
            ulong i=ulong(hit.primitive_id)*3ul;
            float3 bary=float3(1-hit.triangle_barycentric_coord.x-hit.triangle_barycentric_coord.y,hit.triangle_barycentric_coord);
            SceneVertex a=vertices[i],b=vertices[i+1],c=vertices[i+2];
            float3 p=a.position.xyz*bary.x+b.position.xyz*bary.y+c.position.xyz*bary.z;
            float3 geometric=normalize(cross(b.position.xyz-a.position.xyz,c.position.xyz-a.position.xyz));
            if(dot(geometric,r.direction)>0)geometric=-geometric;
            float3 n=normalize(a.normal.xyz*bary.x+b.normal.xyz*bary.y+c.normal.xyz*bary.z);
            if(dot(n,geometric)<0)n=-n;
            if(dot(n,r.direction)>=-0.001f)n=geometric;
            SceneMaterial material=materials[materialIndices[hit.primitive_id]];
            float epsilon=max(0.001f,maxComponent(abs(p))*0.000008f);
            if(material.properties.w>0) {
                float reflectance=thinSheetReflectance(dot(geometric,r.direction));
                float3 reflected=reflect(r.direction,geometric);
                if(rays<3 && maxComponent(throughput)*reflectance>0.002f) {
                    origins[rays]=p+geometric*epsilon;directions[rays]=reflected;weights[rays]=throughput*reflectance;++rays;
                } else {color+=throughput*reflectance*skyRadiance(reflected,u,false);}
                throughput*=clamp(material.albedo.rgb,0.0f,1.0f)*saturate(material.properties.w)*(1-reflectance);
                if(maxComponent(throughput)<0.0001f)break;
                r.origin=p-geometric*epsilon;r.min_distance=epsilon*0.25f;continue;
            }
            Surface surface=surfaceAt(material,p,n,max(0.00001f,distance(p,u.origin.xyz)*cone),night,u.animation.x);
            if(int(material.properties.z+0.5f)==17) {color+=throughput*surface.color*surface.emission;break;}
            float reflectionMix=rays<3 ? 1-smoothstep(0.04f,0.42f,surface.roughness):0;
            float3 fresnel=fresnelSchlick(max(dot(surface.normal,-r.direction),0.0f),mix(float3(surface.dielectricF0),surface.color,surface.metallic));
            if(maxComponent(throughput*fresnel)*reflectionMix<0.005f)reflectionMix=0;
            color+=throughput*directLighting<HasTraffic>(surface,p,geometric,-r.direction,scene,staticTriangles,
                vertices,materialIndices,materials,u,lights,grid,ranges,indices,reflectionMix,
                traffic,trafficGrid,trafficRanges,trafficIndices,trafficLights);
            if(reflectionMix>0) {
                origins[rays]=p+geometric*epsilon;directions[rays]=reflect(r.direction,surface.normal);
                if(dot(directions[rays],geometric)<=0)directions[rays]=reflect(r.direction,geometric);
                weights[rays]=throughput*fresnel*reflectionMix;++rays;
            }
            break;
        }
    }
    if(primaryDepth<59999) {
        float density=u.animation.w>0 ? u.animation.w:(night ? 0.00010f:0.00028f);
        float haze=1-exp(-primaryDepth*density);
        float3 scattering=night ? skyRadiance(directions[0],u,false):daylightAerialPerspective(directions[0],u);
        color=mix(color,scattering*0.8f,haze);
    }
    output.write(float4(all(isfinite(color)) ? max(color,0.0f):float3(0),primaryDepth),tid);
}

kernel void directRayTrace(texture2d<float,access::write> output [[texture(0)]],
                          constant FrameUniforms &u [[buffer(0)]],
                          const device SceneVertex *vertices [[buffer(1)]],const device uint *materialIndices [[buffer(2)]],
                          const device SceneMaterial *materials [[buffer(3)]],primitive_acceleration_structure scene [[buffer(4)]],
                          const device SceneLight *lights [[buffer(5)]],constant LightGridHeader &grid [[buffer(6)]],
                          const device uint2 *ranges [[buffer(7)]],const device uint *indices [[buffer(8)]],
                          uint2 tid [[thread_position_in_grid]]) {
    traceDirect<false>(output,u,vertices,materialIndices,materials,scene,lights,grid,ranges,indices,0,tid);
}
kernel void directRayTraceTraffic(texture2d<float,access::write> output [[texture(0)]],
                          constant FrameUniforms &u [[buffer(0)]],
                          const device SceneVertex *vertices [[buffer(1)]],const device uint *materialIndices [[buffer(2)]],
                          const device SceneMaterial *materials [[buffer(3)]],instance_acceleration_structure scene [[buffer(4)]],
                          const device SceneLight *lights [[buffer(5)]],constant LightGridHeader &grid [[buffer(6)]],
                          const device uint2 *ranges [[buffer(7)]],const device uint *indices [[buffer(8)]],
                          constant uint4 &traffic [[buffer(9)]],constant LightGridHeader &trafficGrid [[buffer(10)]],
                          const device uint2 *trafficRanges [[buffer(11)]],const device uint *trafficIndices [[buffer(12)]],
                          const device SceneLight *trafficLights [[buffer(13)]],uint2 tid [[thread_position_in_grid]]) {
    traceDirect<true>(output,u,vertices,materialIndices,materials,scene,lights,grid,ranges,indices,traffic.x,tid,
        &traffic,&trafficGrid,trafficRanges,trafficIndices,trafficLights);
}

// Direct-only spatial edge presentation. Following NVIDIA's FXAA guidance,
// contrast and interpolation operate AFTER tone mapping and sRGB encoding:
// averaging HDR first would erase coverage beside very bright sources.
// https://developer.download.nvidia.com/assets/gamedev/files/sdk/11/FXAA_WhitePaper.pdf
float3 directDisplayTexel(texture2d<float> radiance,int2 pixel,float exposure) {
    int2 size=int2(radiance.get_width(),radiance.get_height());
    return encodeSRGB(filmic(radiance.read(uint2(clamp(pixel,int2(0),size-1))).rgb*exposure));
}
float3 directDisplaySample(texture2d<float> radiance,float2 uv,float exposure) {
    float2 pixel=uv*float2(radiance.get_width(),radiance.get_height())-0.5f;
    int2 base=int2(floor(pixel));float2 fraction=fract(pixel);
    return mix(mix(directDisplayTexel(radiance,base,exposure),directDisplayTexel(radiance,base+int2(1,0),exposure),fraction.x),
               mix(directDisplayTexel(radiance,base+int2(0,1),exposure),directDisplayTexel(radiance,base+int2(1,1),exposure),fraction.x),fraction.y);
}
float3 directEdgeColor(texture2d<float> radiance,float2 uv,constant FrameUniforms &u) {
    float exposure=max(u.settings.x,0.0f);
    float2 texel=1.0f/float2(radiance.get_width(),radiance.get_height());
    float3 center=directDisplaySample(radiance,uv,exposure);
    float3 nw=directDisplaySample(radiance,uv+float2(-1,-1)*texel,exposure);
    float3 ne=directDisplaySample(radiance,uv+float2(1,-1)*texel,exposure);
    float3 sw=directDisplaySample(radiance,uv+float2(-1,1)*texel,exposure);
    float3 se=directDisplaySample(radiance,uv+float2(1,1)*texel,exposure);
    const float3 luma=float3(0.299f,0.587f,0.114f);
    float m=dot(center,luma),a=dot(nw,luma),b=dot(ne,luma),c=dot(sw,luma),d=dot(se,luma);
    float lo=min(m,min(min(a,b),min(c,d))),hi=max(m,max(max(a,b),max(c,d)));
    // Leave low-contrast material/sky detail alone. These thresholds match the
    // paper's high-quality contrast settings; there is no temporal blending.
    if(hi-lo<max(1.0f/16.0f,hi*(1.0f/8.0f)))return center;
    float2 direction=float2(-((a+b)-(c+d)),(a+c)-(b+d));
    float reduce=max((a+b+c+d)*(0.25f/8.0f),1.0f/128.0f);
    direction=clamp(direction/(min(abs(direction.x),abs(direction.y))+reduce),float2(-8),float2(8))*texel;
    float3 narrow=0.5f*(directDisplaySample(radiance,uv-direction/6.0f,exposure)
                      +directDisplaySample(radiance,uv+direction/6.0f,exposure));
    float3 wide=narrow*0.5f+0.25f*(directDisplaySample(radiance,uv-direction*0.5f,exposure)
                               +directDisplaySample(radiance,uv+direction*0.5f,exposure));
    float wideLuma=dot(wide,luma);
    float3 filtered=wideLuma<lo || wideLuma>hi ? narrow:wide;
    // Retain center coverage to protect thin railings/mortar and avoid turning
    // a short edge estimate into an unnecessarily broad blur.
    return mix(center,filtered,0.6f);
}
fragment float4 directPresentFragment(FullscreenOut in [[stage_in]],
                                      texture2d<float> radiance [[texture(0)]],
                                      constant FrameUniforms &u [[buffer(0)]]) {
    return float4(directEdgeColor(radiance,in.uv,u),1);
}
fragment float4 directFocusedPresentFragment(FullscreenOut in [[stage_in]],
                                             texture2d<float> radiance [[texture(0)]],
                                             texture2d<float> depth [[texture(1)]],
                                             constant FrameUniforms &u [[buffer(0)]],
                                             const device float4 *volumes [[buffer(1)]]) {
    float3 color=directEdgeColor(radiance,in.uv,u);
    // Selection still uses the unfiltered center-ray depth. Do not spread
    // landmark identity across an occluding edge or into the sky.
    int2 pixel=int2(in.uv*float2(depth.get_width(),depth.get_height()));
    if(selectedPixel(pixel,depth,u,volumes)) {
        bool edge=!selectedPixel(pixel+int2(2,0),depth,u,volumes)||!selectedPixel(pixel-int2(2,0),depth,u,volumes)
            ||!selectedPixel(pixel+int2(0,2),depth,u,volumes)||!selectedPixel(pixel-int2(0,2),depth,u,volumes);
        color=mix(color,float3(1.0f,0.78f,0.27f),edge ? 0.86f:0.19f);
    }
    return float4(color,1);
}
