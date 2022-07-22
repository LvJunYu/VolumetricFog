Shader "LYU/VolumetricFog/Fog"
{
    Properties
    {
        [Header(FogColor)]
        _FogColor("雾的颜色", Color) = (1,1,1,1)
        [Toggle]_EnableLightColor("受光照影响", Float) = 1.0
        _FogAlpha("雾的透视度", Range(0.0, 10.0)) = 0.75
        _Density("雾的密度", Range(0.0, 1.0)) = 0.01
        _FogColorIntensity("光照强度", Range(0.0, 20.0)) = 5.0
        
        [Toggle(_ReceiveShadow)] _ShadowEnable("接受阴影", Float) = 1.0
        [ShowIfPropertyConditions(_ShadowEnable, Equal, 1)] _ShadowIntensity("阴影强度", Range(0.0, 1.0)) = 1.0
        _HGFactor("相位系数（大于0逆光更亮）", Range(-0.96, 0.96)) = 0.3
//        [HideInInspector] _MaxLightValue("亮度最大值Clamp", Range(0, 10)) = 10

        [Header(ColorGradient)]
        [Toggle]_ColorGradientEnable("底部颜色渐变", Float) = 0.0
        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _FogColorBottom("底部颜色", Color) = (0.4709861,0.5542898,0.6792453,1)
        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _FogColorPos("颜色渐变高度", Float) = 2
        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _FogColorRange("颜色渐变过渡", Float) = 1
        //        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _BottomShadow("底部修改", Range(-1.0, 1.0)) = 0.0
        //        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _TopShadow("顶部修改", Range(-1.0, 1.0)) = 0.0

        [Header(HeightGradient)]
        [KeywordEnum(No, Multiply, Subtract)]_HeightTransitionEnable("密度高度衰减", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _GradientStart("衰减开始", Float) = 0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _GradientDis("衰减距离（从Cube底部开始，使用高度图则从高度图的高度开始）", Float) = 10
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _HeightPower("衰减曲线（值越大衰减越快）", Range(0.1,10)) = 1

        [Toggle(_UseHeightMap)][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _HeightMapEnable("使用高度图", Float) = 0.0
        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _HeightMap("高度图", 2D) = "black" {}
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _ReduceUnderHeight("遮蔽下削弱", Range(0.0, 1.0)) = 0.0
        [Toggle][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _LowChangeEnable("修改低处雾", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _LowChangeEnable, Equal, 1)] _LowReduceStart("低处调整的阈值", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _LowChangeEnable, Equal, 1)] _LowReduce("修改低处雾", Range(-1.0, 1.0)) = 0.0
        [Toggle][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _HighChangeEnable("修改高处雾", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _HighChangeEnable, Equal, 1)] _HighEnhanceStart("高处调整的阈值", Float) = 100.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _HighChangeEnable, Equal, 1)] _HighEnhance("修改高处雾", Range(-1.0, 1.0)) = 0.0
        //        [HideInInspector] _HeightMapCenterRange("高度图中心和范围", Vector) = (0,0,0,100)
        //        [HideInInspector] _HeightMapDepth("高度图深度", Float) = 10

        [Header(NoiseMap)]
        [KeywordEnum(NoTexture, 3DTexture, 2DTexture)]_VolumeMapEnable("使用噪声模拟雾的密度和飘动效果", Float) = 0.0
        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMap("3D噪声图", 3D) = "white" {}

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapSpeedAll("整体速度", Vector) = (1,1,1,1)
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapSpeedScale("整体Tiling", Range(0.0, 2.0)) = 1.0
        [KeywordEnum(R, RG, RGB, RGBA)] [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _NoiseLayerCount("噪声层数", Int) = 0

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapScale("(R) 噪声Tiling", Range(0.0, 0.2)) = 0.1
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapIntensity("(R) 噪声影响强度", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapPow("(R) 噪声Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapSpeed("(R) 雾的飘动速度", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapScale2("(G) 噪声Tiling", Range(0.0, 0.2)) = 0.05
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapIntensity2("(G) 噪声影响强度", Range(0.0, 2.0)) = 0.4
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapPow2("(G) 噪声Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapSpeed2("(G) 雾的飘动速度", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapScale3("(B) 噪声Tiling", Range(0.0, 0.2)) = 0.05
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapIntensity3("(B) 噪声影响强度", Range(0.0, 2.0)) = 0.3
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapPow3("(B) 噪声Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapSpeed3("(B) 雾的飘动速度", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapScale4("(A) 噪声Tiling", Range(0.0, 0.2)) = 0.05
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapIntensity4("(A) 噪声影响强度", Range(0.0, 2.0)) = 0.2
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapPow4("(A) 噪声Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapSpeed4("(A) 雾的飘动速度", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapSpeedDown("后两层(B、A)对底部影响削弱", Range(0.01, 2.0)) = 1.0

        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _CloudNoiseMap("2D噪声图", 2D) = "white" {}
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _VolumeHeight("2D噪声高度强度", Range(0.0, 2.0)) = 1
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _VolumeMapScale_2D("2D噪声Tiling", Range(0.0, 0.2)) = 0.1
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _VolumeMapSpeed_2D("雾的速度(XY), Power(W)", Vector) = (0.1,0,0,1)

        [Header(DetailNoiseMap)]
        [Toggle(_UseDetailNoise)]_DetailNoiseEnable("增加噪声扭曲", Float) = 0.0
        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)]_DetailNoiseMap("扭曲噪声图", 3D) = "white" {}
        [ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)] _DetailNoiseMapScale("细节噪声Tiling", Range(0.0, 0.1)) = 0.05
        [ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)] _DetailNoiseIntensity("细节噪声强度", Range(0.0, 10.0)) = 1.0
        [ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)] _DetailNoiseSpeed("细节噪声速度", Range(0.0, 0.1)) = 0.01

        [Header(MaxDistance)]
        [Toggle(_UseMaxDistance)]_MaxDistanceEnable("体积雾最远距离（体积雾范围过大时开启，提高精度）", Float) = 1.0
        [ShowIfPropertyConditions(_MaxDistanceEnable, Equal, 1)] _MaxDistance("体积雾最远距离", Float) = 50

        [Header(BorderTransition)]
        [Toggle(_UseBorderTransition)]_BorderGradientEnable("开启边缘过渡（Cube不能有旋转）", Float) = 0.0
        [ShowIfPropertyConditions(_BorderGradientEnable, Equal, 1)] _BorderTransition("XZ方向过渡程度", Range(0, 1)) = 0

        [Header(NearDamp)]
        [Toggle(_UseNearDamp)]_NearDampEnable("近处没有雾", Float) = 0.0
        [ShowIfPropertyConditions(_NearDampEnable, Equal, 1)] _FogStartDistance("没雾的范围", Float) = 10.0
        [ShowIfPropertyConditions(_NearDampEnable, Equal, 1)] _DampDistance("渐变范围", Float) = 10.0

        [Header(SelfShadow)][Toggle(_UseSelfShadow)]_SelfShadowEnable("开启自阴影", Float) = 0.0
        [ShowIfPropertyConditions(_SelfShadowEnable, Equal, 1)] _SelfShadowOffset("自阴影偏移距离", Range(0, 5)) = 1
        [ShowIfPropertyConditions(_SelfShadowEnable, Equal, 1)] _SelfShadowIntensity("自阴影强度", Range(0, 3)) = 1

        [Header(Denoise)]
//        _DenoiseEnable("降噪1（可能导致抖动）", Range(0, 1)) = 0.0
        _ReduceNoiseTiling("降低相机移动时噪点（可能导致pattern或jitter）", Range(0, 1)) = 0
        //        [Toggle(_Use_PCG_Noise)]_UsePCGNoise("降噪3-用PCG噪声算法", float) = 0.0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "Queue" = "Transparent+1" "RenderPipeline" = "UniversalPipeline" "DisableBatching"="True"
        }
        LOD 300

        Pass
        {
            Tags
            {
                "LightMode" = "VolumetricFog"
            }

            ZTest Always
            ZWrite Off
            Cull Front
            Blend One SrcAlpha, DstAlpha Zero

            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _NoiseEnable
            #pragma multi_compile_fragment _ _MultiScattering_Enable

            // #pragma shader_feature_local _Use_PCG_Noise
            #pragma shader_feature_local _VOLUMEMAPENABLE_NOTEXTURE _VOLUMEMAPENABLE_3DTEXTURE _VOLUMEMAPENABLE_2DTEXTURE
            #pragma shader_feature_local _HEIGHTTRANSITIONENABLE_NO _HEIGHTTRANSITIONENABLE_MULTIPLY _HEIGHTTRANSITIONENABLE_SUBTRACT
            #pragma shader_feature_local _UseMaxDistance
            #pragma shader_feature_local _UseBorderTransition
            #pragma shader_feature_local _UseDetailNoise
            #pragma shader_feature_local _UseHeightMap
            #pragma shader_feature_local _ReceiveShadow
            #pragma shader_feature_local _UseNearDamp
            #pragma shader_feature_local _UseSelfShadow

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            half3 _FogColor;
            half _ColorGradientEnable;
            half3 _FogColorBottom;
            half _FogColorPos;
            half _FogColorRange;
            half _FogColorIntensity;
            half _ShadowIntensity;
            half _FogAlpha;
            half _EnableLightColor;

            half4 _VolumeMapSpeedAll;
            half _VolumeMapSpeedScale;
            half _VolumeMapSpeedDown;
            // half _BottomShadow;
            // half _TopShadow;
            int _NoiseLayerCount;
            half _VolumeMapScale;
            half _VolumeMapIntensity;
            half4 _VolumeMapSpeed;
            half _VolumeMapPow;
            half _VolumeMapScale2;
            half _VolumeMapIntensity2;
            half4 _VolumeMapSpeed2;
            half _VolumeMapPow2;
            half _VolumeMapScale3;
            half _VolumeMapIntensity3;
            half4 _VolumeMapSpeed3;
            half _VolumeMapPow3;
            half _VolumeMapScale4;
            half _VolumeMapIntensity4;
            half4 _VolumeMapSpeed4;
            half _VolumeMapPow4;
            half _VolumeMapScale_2D;
            half4 _VolumeMapSpeed_2D;

            half _VolumeHeight;
            half _Density;
            half _HGFactor;
            // half _MaxLightValue;

            half _GradientStart;
            half _GradientDis;
            half _HeightPower;
            
            half _ReduceNoiseTiling;
            half _ReduceUnderHeight;
            half _LowChangeEnable;
            half _HighChangeEnable;
            half _LowReduce;
            half _LowReduceStart;
            half _HighEnhance;
            half _HighEnhanceStart;
            // float4 _HeightMapCenterRange;
            // float _HeightMapDepth;
            // half _HeightBottomGradient;

            float _MaxDistance;
            half _BorderTransition;

            half _DetailNoiseMapScale;
            half _DetailNoiseIntensity;
            half _DetailNoiseSpeed;

            half _FogStartDistance;
            half _DampDistance;

            half _SelfShadowOffset;
            half _SelfShadowIntensity;
            CBUFFER_END

            float4 _FogTextureSize;
            float4 _FogParam;
            float4 _NoiseMap_TexelSize;
            float4x4 _MyInvViewProjMatrix; // Unity提供的VP逆矩阵在不同版本处理不同，这里自己传入
            half _CameraMoveScale;

            #define _Jitter _FogParam.x
            #define _NoiseScale _FogParam.z
            #define _Step_MAX uint(_FogParam.y)
            #define _FrameNum uint(_FogParam.w)
            // #if _HighQuality
            // #define _Step_MAX 64
            // #else
            // #define _Step_MAX 8
            // #endif

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);
            TEXTURE2D_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE3D(_VolumeMap);
            SAMPLER(sampler_VolumeMap);
            TEXTURE3D(_DetailNoiseMap);
            SAMPLER(sampler_DetailNoiseMap);
            TEXTURE2D_FLOAT(_HeightMap);
            SAMPLER(sampler_HeightMap);
            TEXTURE2D(_CloudNoiseMap);
            SAMPLER(sampler_CloudNoiseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float3 posWS : TEXCOORD0;
                float4 screenUV : TEXCOORD1;
                float4 posCS : SV_POSITION;
            };

            struct GlobalData
            {
                float3 center;
                float3 range;
                half density;
                half lowThreshold;
                half highThreshold;
            };

            struct RayMarchData
            {
                float3 stepVec3;
                float stepDistance;
                float3 curPos;
                float curDistance;
                half3 pos01;
                half heightRaw01; // 考虑高度图的归一化高度
                half fixedHeight01; // 考虑高度图和衰减距离的归一化高度
                half underHeightMap; // 当前距离高度图的距离
                half lowRange; // 低处雾
                half highRange; // 高处雾
            };

            #include "VolumeCommon.hlsl"
            #include "VolumeLighting.hlsl"

            uint3 Rand3DPCG16(int3 p)
            {
                // taking a signed int then reinterpreting as unsigned gives good behavior for negatives
                uint3 v = uint3(p);

                // Linear congruential step. These LCG constants are from Numerical Recipies
                // For additional #'s, PCG would do multiple LCG steps and scramble each on output
                // So v here is the RNG state
                v = v * 1664525u + 1013904223u;

                // PCG uses xorshift for the final shuffle, but it is expensive (and cheap
                // versions of xorshift have visible artifacts). Instead, use simple MAD Feistel steps
                //
                // Feistel ciphers divide the state into separate parts (usually by bits)
                // then apply a series of permutation steps one part at a time. The permutations
                // use a reversible operation (usually ^) to part being updated with the result of
                // a permutation function on the other parts and the key.
                //
                // In this case, I'm using v.x, v.y and v.z as the parts, using + instead of ^ for
                // the combination function, and just multiplying the other two parts (no key) for 
                // the permutation function.
                //
                // That gives a simple mad per round.
                v.x += v.y * v.z;
                v.y += v.z * v.x;
                v.z += v.x * v.y;
                v.x += v.y * v.z;
                v.y += v.z * v.x;
                v.z += v.x * v.y;

                // only top 16 bits are well shuffled
                return v >> 16u;
            }

            half GetNoise(float2 uv, float2 tiling)
            {
                #if _NoiseEnable
                {
                    uv = fmod((uv * _FogTextureSize.xy), uint2(tiling)) / _NoiseMap_TexelSize.xy;
                    return SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uv).r * _NoiseScale;
                }
                #else
                {
                    return 0;
                }
                #endif
            }

            half PhaseHG(float3 lightDir, float3 viewDir)
            {
                if (_HGFactor == 0)
                {
                    return 1;
                }
                half g = _HGFactor;
                half x = 1 + g * dot(viewDir, lightDir);
                return (1 - g * g) / (x * x);
                // 1.5-exponent is quite costly, use Schlick phase function approximation
                // http://www2.imm.dtu.dk/pubdb/edoc/imm6267.pdf
                //return (1 - g * g) / (pow(1 + g * g - 2 * g * dot(viewDir, lightDir), 1.5));
            }

            half GetOffset(float2 screenUV)
            {
                // #if _Use_PCG_Noise & _NoiseEnable
                // {
                //     uint2 texelID = uint2(screenUV * _FogTextureSize.xy);
                //     return float(Rand3DPCG16(int3(texelID, fmod(_FrameNum, 64))).x) / 0xffff;
                // }
                // #endif

                uint2 tiling = _NoiseMap_TexelSize.xy;
                half tilingScale = _ReduceNoiseTiling * _CameraMoveScale;
                if (tilingScale)
                {
                    tiling /= pow(2, uint(tilingScale * 5));
                }
                half jitterScale = 1 - tilingScale;
                return frac(_Jitter * jitterScale + GetNoise(screenUV, tiling)) - 0.5;
            }

            RayMarchData InitRayMarchData(GlobalData globalData, float3 startPos, float rayMarchLength, float3 dir,
                                          float2 screenUV)
            {
                RayMarchData data;
                float stepDelta = 1.0 / _Step_MAX;
                data.stepDistance = stepDelta * rayMarchLength;
                data.stepVec3 = data.stepDistance * dir;
                data.curDistance = 0;
                data.curPos = startPos + data.stepVec3 * GetOffset(screenUV);

                UpdatePosInfo(globalData, data);
                return data;
            }

            void UpdateNextStep(GlobalData global_data, inout RayMarchData data)
            {
                data.curPos += data.stepVec3;
                data.curDistance += data.stepDistance;
                UpdatePosInfo(global_data, data);
            }

            GlobalData InitGlobalData()
            {
                GlobalData data;
                data.density = max(_Density, 0.000001);
                GetCenterAndRange(data.center, data.range);
                data.lowThreshold = CalculateHeight01(data, _LowReduceStart);
                data.highThreshold = CalculateHeight01(data, _HighEnhanceStart);
                return data;
            }

            half4 RayMarching(float3 startPos, float rayMarchLength, float3 dir, float2 screenUV)
            {
                half4 accuColor = half4(0, 0, 0, 1);
                if (rayMarchLength > 0)
                {
                    GlobalData global_data = InitGlobalData();
                    RayMarchData data = InitRayMarchData(global_data, startPos, rayMarchLength, dir, screenUV);
                    Light light = GetMainLight();
                    [loop]
                    for (uint i = 0; i < _Step_MAX; i++)
                    {
                        half curDensity = GetDensity(data, global_data);
                        CalculateLighting(data, global_data, curDensity, light, accuColor);
                        UpdateNextStep(global_data, data);
                    }

                    half phase = PhaseHG(light.direction, -dir);
                    // accuColor.rgb = min(_MaxLightValue, phase * accuColor.rgb);
                    accuColor.rgb *= phase;
                    if (_EnableLightColor > 0)
                        accuColor.rgb *= light.color;

                    accuColor.a = saturate(1 - (1 - accuColor.a) * _FogAlpha);
                }

                return accuColor;
            }

            struct Output
            {
                float4 color : SV_Target0;
                float4 fogDepth : SV_Target1;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.posCS = vertexInput.positionCS;
                output.posWS = vertexInput.positionWS;
                output.screenUV = ComputeScreenPos(output.posCS);
                return output;
            }

            Output frag(Varyings input)
            {
                float3 viewDirWS = normalize(input.posWS - GetCameraPositionWS());
                float2 screenUV = input.screenUV.xy / input.screenUV.w;
                float opaqueDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
                float maxDepth = GetMaxDepth(opaqueDepth);
                float4 intersect = IntersectCube(viewDirWS, screenUV, maxDepth);
                half4 res = RayMarching(intersect.xyz, intersect.w, viewDirWS, screenUV);
                // if (all(res.rgb == 0))
                // {
                //     res.a = 1;
                // }
                Output output;
                output.color = res;
                output.fogDepth = float4(GetFogDepth(maxDepth, input.posCS.z, opaqueDepth), 0, 0, 0); // depth override, so alpha is zero. CompareDepth(maxDepth, input.posCS.z);
                return output;
            }
            ENDHLSL
        }
    }
}