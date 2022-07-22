#ifndef VolumeLighting_Include
#define VolumeLighting_Include

#include "VolumeCommon.hlsl"

#if UNITY_REVERSED_Z
#define CompareDepth(a, b) max(a, b)
#else
#define CompareDepth(a, b) min(a, b)
#endif

// The depth of the volumetric fog is hard to define.
// Use transmittance weighted depth in Red Dead Redemption 2, slide 35 of https://advances.realtimerendering.com/s2019/index.htm,
// but it is hard to do depth rejection because the depth is transmittance dependent.
// So I tried to use the fog's pixel depth, but it has problems when the fogs override.
// At last, I use opaque depth only.
float GetFogDepth(float maxDepth, float pixelDepth, float opaqueDepth)
{
    return opaqueDepth;
    // return CompareDepth(maxDepth, pixelDepth);
}

float GetMaxDepth(float depth)
{
    #if _UseMaxDistance
    {
        depth = CompareDepth(depth, LinearDepthToZBuffer(_MaxDistance, _ZBufferParams));
    }
    #endif
    return depth;
}

float3 TransformWorldToObjectDirFloat(float3 dirWS)
{
    return normalize(mul((float3x3)GetWorldToObjectMatrix(), dirWS));
}

float4 IntersectCube(float3 viewDir, float2 screenUV, float maxDepth)
{
    float3 maxPosWS = ReconstructWorldPos(screenUV, maxDepth);
    float3 localCameraPos = TransformWorldToObject(GetCameraPositionWS());
    float3 localViewDir = TransformWorldToObjectDirFloat(viewDir);
    float3 invLocalViewDir = 1.0 / localViewDir;
    float3 intersect1 = (-0.5 - localCameraPos) * invLocalViewDir;
    float3 intersect2 = (0.5 - localCameraPos) * invLocalViewDir;
    float3 tEnterVec3 = min(intersect1, intersect2);
    float3 tExitVec3 = max(intersect1, intersect2);
    float tEnter = max(max(tEnterVec3.x, tEnterVec3.y), tEnterVec3.z);
    float tExit = min(min(tExitVec3.x, tExitVec3.y), tExitVec3.z);

    float3 localMaxPos = TransformWorldToObject(maxPosWS);
    float tMax = length(localMaxPos - localCameraPos); // / length(localViewDir);
    tEnter = min(tEnter, tMax);
    tExit = min(tExit, tMax);

    tEnter = max(tEnter, 0);
    tExit = max(tEnter, tExit);
    float3 localStartPos = localCameraPos + localViewDir * tEnter;
    float3 localEndPos = localCameraPos + localViewDir * tExit;
    float3 worldStartPos = TransformObjectToWorld(localStartPos);
    float3 worldEndPos = TransformObjectToWorld(localEndPos);
    return float4(worldStartPos, length(worldEndPos - worldStartPos));
}

void GetCenterAndRange(out float3 center, out float3 scale)
{
    float4x4 objectToWorld = GetObjectToWorldMatrix();
    center = float3(objectToWorld._14, objectToWorld._24, objectToWorld._34);
    scale = float3(objectToWorld._11, objectToWorld._22, objectToWorld._33);
}

half CalculateHeight01(GlobalData global_data, float height)
{
    return saturate((height - global_data.center.y) / global_data.range.y + 0.5);
}

half3 CalculatePos01(float3 pos, float3 center, float3 scale)
{
    return saturate((pos - center) / scale + 0.5);
}

float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
{
    return new_min + (original_value - original_min) / (original_max - original_min) * (new_max - new_min);
}

float RemapClamped(float original_value, float original_min, float original_max, float new_min,
                   float new_max)
{
    return new_min + (saturate((original_value - original_min) / (original_max - original_min)) * (new_max -
        new_min));
}

half CalculateDamp(RayMarchData data)
{
    half damp = 1;
    #if _UseBorderTransition
    {
        #if 0 //局部空间需要矩阵运算比较费
        {
            float3 distanceToBorder = 0.5 - abs(TransformWorldToObject(data.curPos));
            float minDis = min(distanceToBorder.x, distanceToBorder.z);
            damp *= smoothstep(0, _BorderTransition * 0.5, minDis);
        }
        #else
        {
            // 使用模型矩阵计算，矩阵不能带旋转
            float2 distanceToBorder = 0.5 - abs(data.pos01.xz - 0.5);
            float minDis = min(distanceToBorder.x, distanceToBorder.y);
            damp *= smoothstep(0, _BorderTransition * 0.5, minDis);
        }
        #endif
    }
    #endif

    #if _UseNearDamp
    {
        float distance = length(GetCameraPositionWS() - data.curPos);
        damp *= saturate((distance - _FogStartDistance) / _DampDistance);
    }
    #endif

    return damp;
}

void CalculateFixedHeight01(GlobalData global_data, inout RayMarchData data)
{
    data.fixedHeight01 = data.pos01.y;
    data.heightRaw01 = data.pos01.y;
    data.underHeightMap = 0;
    data.lowRange = 0;
    data.highRange = 0;
    #if _HEIGHTTRANSITIONENABLE_MULTIPLY | _HEIGHTTRANSITIONENABLE_SUBTRACT
    {
        half height01 = data.pos01.y;
    #if _UseHeightMap
        {
            // float2 heightUv = (pos.xz - global_data.center.xz) / max(global_data.range.x, global_data.range.z) + 0.5;
            half sample01 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, data.pos01.xz, 0).r;

            data.heightRaw01 = saturate(height01 - sample01);

            // 在高度图下的距离
            data.underHeightMap = max(0, sample01 - data.pos01.y);

            // 低处雾
            // half low = saturate(_LowReduceStart / global_data.range.y);
            data.lowRange = RemapClamped(sample01, 0, global_data.lowThreshold, 1, 0); 

            // 高处雾
            // half high = saturate(_HighEnhanceStart / global_data.range.y);
            data.highRange = RemapClamped(sample01, global_data.highThreshold, 1, 0, 1);

            half dampLow = lerp(1, _LowReduce * _LowChangeEnable + 1, data.lowRange);
            half dampHigh = lerp(1, _HighEnhance * _HighChangeEnable + 1, data.highRange);
            sample01 *= dampLow * dampHigh;
            height01 -= sample01;
        }
    #endif

        half start = _GradientStart / global_data.range.y;
        half gradient = _GradientDis / global_data.range.y;
        half fixHeight01 = saturate((height01 - start) / max(0.0001, gradient));
        data.fixedHeight01 = 1 - pow(1 - fixHeight01, _HeightPower);
    }
    #endif
}

void UpdatePosInfo(GlobalData cubeData, inout RayMarchData data)
{
    data.pos01 = CalculatePos01(data.curPos, cubeData.center, cubeData.range);
    CalculateFixedHeight01(cubeData, data);
}

half DampWithHeight(RayMarchData data)
{
    half dampUnderHeightmap = 1 - saturate(data.underHeightMap * _ReduceUnderHeight * 100);
    // half dampLow = lerp(1, _LowReduce + 1, data.lowRange);
    // half dampHigh = lerp(1, _HighEnhance + 1, data.highRange);
    return dampUnderHeightmap;
}

half CalculateNoise(RayMarchData data)
{
    half volumeNoise = 1;
    float3 posUv = data.curPos;
    #if _UseDetailNoise
    {
        float3 detailUV = posUv * _DetailNoiseMapScale + _Time.y * -_DetailNoiseSpeed;
        half3 detailNoise = SAMPLE_TEXTURE3D(_DetailNoiseMap, sampler_DetailNoiseMap, detailUV).xyz;
        detailNoise = lerp(0.5, detailNoise, _DetailNoiseIntensity * 3) - 0.5;
        posUv += detailNoise;
    }
    #endif

    #if _VOLUMEMAPENABLE_3DTEXTURE
        posUv *= _VolumeMapSpeedScale;
        float3 time = -_Time.y * _VolumeMapSpeedAll.xyz;
        float3 volumeUV = time * _VolumeMapSpeed.xyz + posUv * _VolumeMapScale;
        volumeNoise = SAMPLE_TEXTURE3D_LOD(_VolumeMap, sampler_VolumeMap, volumeUV, 0).x;
        volumeNoise = pow(volumeNoise, _VolumeMapPow) * _VolumeMapIntensity;
        
        if(_NoiseLayerCount > 0.5)
        {
            float3 volumeUV2 = time * _VolumeMapSpeed2.xyz + posUv * _VolumeMapScale2;
            half volumeNoise2 = SAMPLE_TEXTURE3D_LOD(_VolumeMap, sampler_VolumeMap, volumeUV2, 0).y;
            volumeNoise2 = pow(volumeNoise2, _VolumeMapPow2) * _VolumeMapIntensity2;
            volumeNoise += volumeNoise2;
        }

        half volemeNoiseSmall = 0;
        if(_NoiseLayerCount > 1.5)
        {
            float3 volumeUV3 = time * _VolumeMapSpeed3.xyz + posUv * _VolumeMapScale3;
            half volumeNoise3 = SAMPLE_TEXTURE3D_LOD(_VolumeMap, sampler_VolumeMap, volumeUV3, 0).z;
            volumeNoise3 = pow(volumeNoise3, _VolumeMapPow3) * _VolumeMapIntensity3;
            volemeNoiseSmall += volumeNoise3;
        }

        if(_NoiseLayerCount > 2.5)
        {
            float3 volumeUV4 = time * _VolumeMapSpeed4.xyz + posUv * _VolumeMapScale4;
            half volumeNoise4 = SAMPLE_TEXTURE3D_LOD(_VolumeMap, sampler_VolumeMap, volumeUV4, 0).z;
            volumeNoise4 = pow(volumeNoise4, _VolumeMapPow4) * _VolumeMapIntensity4;
            volemeNoiseSmall += volumeNoise4;
        }

        volumeNoise += lerp(0, volemeNoiseSmall, pow(data.fixedHeight01, _VolumeMapSpeedDown));

    #elif _VOLUMEMAPENABLE_2DTEXTURE
        float2 volumeUV2 = _Time.y * -_VolumeMapSpeed_2D.xy + posUv.xz * _VolumeMapScale_2D;
        half4 sampleTex = SAMPLE_TEXTURE2D_LOD(_CloudNoiseMap, sampler_CloudNoiseMap, volumeUV2, 0);
        // float2 uv3 = _Time.y * _VolumeMapSpeed.y + pos.xz * _VolumeMapScale * _VolumeMapSpeed.w;
        // half smallNoise = SAMPLE_TEXTURE3D(_CloudNoiseMap, sampler_CloudNoiseMap, uv3).a;
        volumeNoise = pow(sampleTex.r, _VolumeMapSpeed_2D.w);
        //volumeNoise = lerp(1, volumeNoise, _VolumeMapIntensity);
        volumeNoise *= 1 - saturate(data.pos01.y / (sampleTex.g * _VolumeHeight));
    #endif

    volumeNoise *= DampWithHeight(data);
    return volumeNoise;
}

half GetDensity(RayMarchData data, GlobalData global_data)
{
    half volumeNoise = CalculateNoise(data);

    #if _HEIGHTTRANSITIONENABLE_MULTIPLY
        volumeNoise *= 1 - data.fixedHeight01;
    #elif _HEIGHTTRANSITIONENABLE_SUBTRACT
        volumeNoise = saturate(saturate(volumeNoise) - data.fixedHeight01);// 减法不会降低对比度，保留更多细节
    #endif

    half density = global_data.density;
    density *= volumeNoise;
    density *= CalculateDamp(data);

    return density;
}

half CalculateShadow(Light light, RayMarchData data, GlobalData global_data)
{
    half shadow = 1;
    #if _ReceiveShadow
    {
        shadow = light.shadowAttenuation * light.distanceAttenuation;
        shadow *= MainLightRealtimeShadow(TransformWorldToShadowCoord(data.curPos));
        shadow = LerpWhiteTo(shadow, _ShadowIntensity);
    }
    #endif
    
    #if _UseSelfShadow //自阴影多算一次密度，挺费
    {
        RayMarchData shadowRayMarchData = data;
        shadowRayMarchData.curPos = data.curPos + light.direction * _SelfShadowOffset;
        UpdatePosInfo(global_data, shadowRayMarchData);
        half shadowDensity = GetDensity(shadowRayMarchData, global_data);
        //selfShadow *= saturate(1 - shadowDensity * _SelfShadowIntensity);
        shadow *= exp(- shadowDensity * _SelfShadowIntensity * 30);
    }
    #endif
    return shadow;
}

void CalculateLighting(RayMarchData data, GlobalData global_data, half curDensity, Light light, inout half4 accuColor)
{
    half shadow = CalculateShadow(light, data, global_data);
    half3 fogColor = _FogColor;
    if (_ColorGradientEnable > 0)
    {
        // fogColor *= pow(data.fixedHeight01, 1 / _FogColorBottom * _FogColorBottomPower * 0.1);
        fogColor = lerp(_FogColorBottom, _FogColor, smoothstep(_FogColorPos - _FogColorRange,
                                                               _FogColorPos + _FogColorRange,
                                                               data.heightRaw01 * global_data.range.y));
        // curDensity *= lerp(1 + _BottomShadow, 1 + _TopShadow, data.heightRaw01);
        // fogColor = lerp(_FogColorBottom, _FogColor, saturate(data.fixedHeight01 * _FogColorBottomPower));
        // curDensity *= lerp(1 - _BottomShadow, 1, saturate(data.fixedHeight01 * _FogColorBottomPower));
    }
    // https://www.ea.com/frostbite/news/physically-based-unified-volumetric-rendering-in-frostbite
    // lighting = light * shadow * extinction
    // sliceLightIntegral = lighting * (1 - exp(-extinction * stepDistance)) / extinction
    //                    = light * shadow * (1 - exp(-extinction * stepDistance))
    half lighting = _FogColorIntensity * shadow;
    float sliceTransmittance = exp(-curDensity * data.stepDistance);
    half sliceLightIntegral = lighting;
    sliceLightIntegral *= (1.0 - sliceTransmittance);
    accuColor.rgb += sliceLightIntegral * accuColor.a * fogColor;
    accuColor.a *= sliceTransmittance;
}

#endif
