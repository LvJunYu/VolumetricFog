Shader "LYU/VolumetricFog/Fog"
{
    Properties
    {
        [Header(Fog Setting)]
        _FogColor("Fog Color", Color) = (1,1,1,1)
        [Toggle]_EnableLightColor("Enable Light Color", Float) = 1.0
        _FogAlpha("Fog Alpha", Range(0.0, 10.0)) = 0.75
        _Density("Fog Density", Range(0.0, 1.0)) = 0.01
        _FogColorIntensity("Fog Intensity", Range(0.0, 20.0)) = 5.0

        [Toggle(_ReceiveShadow)] _ShadowEnable("Receive Shadow", Float) = 1.0
        [ShowIfPropertyConditions(_ShadowEnable, Equal, 1)] _ShadowIntensity("Shadow Intensity", Range(0.0, 1.0)) = 1.0
        _HGFactor("HG Factor", Range(-0.96, 0.96)) = 0.3
        //        [HideInInspector] _MaxLightValue("亮度最大值Clamp", Range(0, 10)) = 10

        [Header(Color Gradient)]
        [Toggle]_ColorGradientEnable("Color Gradient Enable", Float) = 0.0
        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _FogColorBottom("Bottom Color", Color) = (0.4709861,0.5542898,0.6792453,1)
        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _FogColorPos("Gradient Position", Float) = 2
        [ShowIfPropertyConditions(_ColorGradientEnable, Equal, 1)] _FogColorRange("Gradient Transition", Float) = 1

        [Header(Density Attenuation)]
        [KeywordEnum(No, Multiply, Subtract)]_HeightTransitionEnable("Density Attenuation Type", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _GradientStart("Attenuation Start", Float) = 0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _GradientDis("Attenuation Distance", Float) = 10
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _HeightPower("Attenuation Power", Range(0.1, 10)) = 1

        [Toggle(_UseHeightMap)][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0)] _HeightMapEnable("Heightmap Enable", Float) = 0.0
        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _HeightMap("Heightmap", 2D) = "black" {}
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _ReduceFloating("Reduce Floating Fog", Range(0.0, 1.0)) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _ReduceUnderHeight("Reduce Under Heightmap", Range(0.0, 1.0)) = 0.0
        [Toggle][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1)] _BasedHeightMapEnable("Attenuation Based on Heightmap", Float) = 1.0
        [Toggle][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _BasedHeightMapEnable, Equal, 1)] _LowChangeEnable("Modify Fog in Low", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _LowChangeEnable, Equal, 1, _BasedHeightMapEnable, Equal, 1)] _LowReduceStart("Threshold in Low", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _LowChangeEnable, Equal, 1, _BasedHeightMapEnable, Equal, 1)] _LowReduce("Intensity in Low", Range(-1.0, 1.0)) = 0.0
        [Toggle][ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _BasedHeightMapEnable, Equal, 1)] _HighChangeEnable("Modify Fog in High", Float) = 0.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _HighChangeEnable, Equal, 1, _BasedHeightMapEnable, Equal, 1)] _HighEnhanceStart("Threshold in High", Float) = 100.0
        [ShowIfPropertyConditions(_HeightTransitionEnable, Greater, 0, _HeightMapEnable, Equal, 1, _HighChangeEnable, Equal, 1, _BasedHeightMapEnable, Equal, 1)] _HighEnhance("Intensity in High", Range(-1.0, 1.0)) = 0.0

        [Header(Noise Map)]
        [KeywordEnum(NoTexture, 3DTexture, 2DTexture)]_VolumeMapEnable("Noise Map Enable", Float) = 0.0
        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMap("3D Noise Map", 3D) = "white" {}

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapSpeedAll("Move Speed", Vector) = (1,1,1,1)
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapSpeedScale("Noise Tiling", Range(0.0, 2.0)) = 1.0
        [KeywordEnum(R, RG, RGB, RGBA)] [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _NoiseLayerCount("Noise Layer", Int) = 0

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapScale("(R) Noise Tiling", Range(0.0, 0.2)) = 0.1
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapIntensity("(R) Noise Intensity", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapPow("(R) Noise Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1)] _VolumeMapSpeed("(R) Noise Speed", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapScale2("(G) Noise Tiling", Range(0.0, 0.2)) = 0.05
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapIntensity2("(G) Noise Intensity", Range(0.0, 2.0)) = 0.4
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapPow2("(G) Noise Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 0)] _VolumeMapSpeed2("(G) Noise Speed", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapScale3("(B) Noise Tiling", Range(0.0, 0.2)) = 0.05
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapIntensity3("(B) Noise Intensity", Range(0.0, 2.0)) = 0.3
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapPow3("(B) Noise Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapSpeed3("(B) Noise Speed", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapScale4("(A) Noise Tiling", Range(0.0, 0.2)) = 0.05
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapIntensity4("(A) Noise Intensity", Range(0.0, 2.0)) = 0.2
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapPow4("(A) Noise Pow", Range(0.0, 2.0)) = 1.0
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 2)] _VolumeMapSpeed4("(A) Noise Speed", Vector) = (0.3,0,0,1)

        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 1, _NoiseLayerCount, Greater, 1)] _VolumeMapSpeedDown("Layers(B and A) Weaken on the Bottom", Range(0.01, 2.0)) = 1.0

        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _CloudNoiseMap("2D Noise Map", 2D) = "white" {}
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _VolumeHeight("2D Noise Intensity", Range(0.0, 2.0)) = 1
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _VolumeMapScale_2D("2D Noise Tiling", Range(0.0, 0.2)) = 0.1
        [ShowIfPropertyConditions(_VolumeMapEnable, Equal, 2)] _VolumeMapSpeed_2D("2D Noise Speed(XY), Power(W)", Vector) = (0.1,0,0,1)

        [Header(Distortion)]
        [Toggle(_UseDetailNoise)]_DetailNoiseEnable("Distortion Enable", Float) = 0.0
        [NoScaleOffset][SinglelineTexture][ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)]_DetailNoiseMap("Distortion Noise Map", 3D) = "white" {}
        [ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)] _DetailNoiseMapScale("Distortion Noise Tiling", Range(0.0, 0.1)) = 0.05
        [ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)] _DetailNoiseIntensity("Distortion Noise Intensity", Range(0.0, 10.0)) = 1.0
        [ShowIfPropertyConditions(_DetailNoiseEnable, Equal, 1)] _DetailNoiseSpeed("Distortion Noise Speed", Range(0.0, 0.1)) = 0.01

        [Header(Max Distance)]
        [Toggle(_UseMaxDistance)]_MaxDistanceEnable("Max Distance Enable", Float) = 1.0
        [ShowIfPropertyConditions(_MaxDistanceEnable, Equal, 1)] _MaxDistance("Max Distance", Float) = 50

        [Header(Border Transition)]
        [Toggle(_UseBorderTransition)]_BorderGradientEnable("Border Transition Enable", Float) = 0.0
        [ShowIfPropertyConditions(_BorderGradientEnable, Equal, 1)] _BorderTransition("Border Transition Intensity", Range(0, 1)) = 0

        [Header(Attenuation Nearby)]
        [Toggle(_UseNearDamp)]_NearDampEnable("Attenuation Nearby Enable", Float) = 0.0
        [ShowIfPropertyConditions(_NearDampEnable, Equal, 1)] _FogStartDistance("Attenuation Start", Float) = 10.0
        [ShowIfPropertyConditions(_NearDampEnable, Equal, 1)] _DampDistance("Attenuation Transition", Float) = 10.0

        [Header(Self Shadow)][Toggle(_UseSelfShadow)]_SelfShadowEnable("Self Shadow Enable", Float) = 0.0
        [ShowIfPropertyConditions(_SelfShadowEnable, Equal, 1)] _SelfShadowOffset("Self Shadow Offset", Range(0, 5)) = 1
        [ShowIfPropertyConditions(_SelfShadowEnable, Equal, 1)] _SelfShadowIntensity("Self Shadow Intensity", Range(0, 3)) = 1

        [Header(Denoise)]
        _ReduceNoiseTiling("Reduce Noisy", Range(0, 1)) = 0
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
            half _ReduceFloating;
            half _BasedHeightMapEnable;
            half _LowChangeEnable;
            half _HighChangeEnable;
            half _LowReduce;
            half _LowReduceStart;
            half _HighEnhance;
            half _HighEnhanceStart;
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
                half3 pos01; // normalized position
                half height01AboveHeightmap; // normalized height above the heightmap
                half fixedHeight01; // normalized height above the heightmap and considering height falloff
                half heightMap01; // the distance under the heightmap
                half lowRange; // the range of low fog
                half highRange; // the range of high fog
            };

            #include "VolumetricFogCommon.hlsl"
            #include "VolumetricFogRaymarch.hlsl"

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
                output.fogDepth = float4(GetFogDepth(maxDepth, input.posCS.z, opaqueDepth), 0, 0, 0);
                // depth override, so alpha is zero. CompareDepth(maxDepth, input.posCS.z);
                return output;
            }
            ENDHLSL
        }
    }
}