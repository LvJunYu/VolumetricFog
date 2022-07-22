#ifndef VolumeCommon_Include
#define VolumeCommon_Include

float3 ReconstructWorldPos(float2 screenPos, float depth)
{
    #if defined(SHADER_API_GLCORE) || defined (SHADER_API_GLES) || defined (SHADER_API_GLES3)
    depth = depth * 2 - 1;
    #endif
    // #if UNITY_UV_STARTS_AT_TOP
    // {
    //     screenPos.y = 1 - screenPos.y;
    // }
    // #endif
    float4 raw = mul(_MyInvViewProjMatrix, float4(screenPos * 2 - 1, depth, 1));
    float3 worldPos = raw.rgb / raw.a;
    return worldPos;
}

// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
float LinearDepthToZBuffer(float linearDepth, float4 zBufferParam)
{
    return (1.0 / linearDepth - zBufferParam.w) / zBufferParam.z;
}


float4 ComputeClipSpacePosition3(float2 positionNDC, float deviceDepth)
{
    #if defined(SHADER_API_GLCORE) || defined (SHADER_API_GLES) || defined (SHADER_API_GLES3)
    deviceDepth = deviceDepth * 2 - 1;
    #endif

    float4 positionCS = float4(positionNDC * 2.0 - 1.0, deviceDepth, 1.0);
    return positionCS;
}

#endif