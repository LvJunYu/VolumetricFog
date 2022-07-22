Shader "Athena/VolumetricFog/Filter"
{
    Properties
    {
        [MainTexture] _MainTex("MainTex", 2D) = "white" {}
        //        [ShaderDebug] _Debug("Debug", Int) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile _ _FilterMode_Gaussian _FilterMode_Bilateral _FilterMode_Bilateral_DepthWeight _FilterMode_Box4x4
            #pragma multi_compile _ _DepthClamp
            // #pragma multi_compile _ _DepthClamp _DepthClamp_Neighbor
            // #pragma shader_feature _ DEBUG

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #ifdef DEBUG
            #include "Packages/com.pwrd.athena-render-pipeline/Shaders/Framework/Modules/Debug/ShaderDebug.hlsl"
            #else
            #define DEBUG_OUTPUT(color, id, s)
            #define SHOW_DEBUG_OUTPUT_FRAGMENT_ONLY(worldPos)
            #endif

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };


            half4 _MainTex_TexelSize;
            half4 _TemporalFilterParam;
            half4 _TemporalFilterParam2;
            half4 _DepthClampParam;
            float4x4 _ClipToLastClip;
            float4x4 _MyInvViewProjMatrix; // Unity提供的VP逆矩阵在不同版本处理不同，这里自己传入

            #define _HistoryWeight _TemporalFilterParam.x
            #define _LastCameraPos _TemporalFilterParam.yzw
            #define _CameraForward _TemporalFilterParam2.xyz
            #define _DepthThresholdMin _DepthClampParam.x
            #define _DepthThresholdMax _DepthClampParam.y
            #define _DepthClampMaxDistance _DepthClampParam.z
            #define _DepthClampWeight _DepthClampParam.w

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_HistoryFogTexture);
            SAMPLER(sampler_HistoryFogTexture);
            TEXTURE2D_FLOAT(_FogDepthTexture);
            SAMPLER(sampler_FogDepthTexture);
            TEXTURE2D_FLOAT(_LastDepthTexture);
            SAMPLER(sampler_LastDepthTexture);

            #include "VolumeCommon.hlsl"

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.uv;
                return output;
            }

            half LuminanceDiff(half4 color0, half4 color1)
            {
                half l0 = Luminance(color0.rgb);
                half l1 = Luminance(color1.rgb);
                return 1 - saturate(2 * abs(l0 - l1));
                // return smoothstep(0.5, 1.0, 1.0 - abs(l0 - l1));
            }

            half DepthWeight(half depthDiff)
            {
                return 1 / (depthDiff * depthDiff + 1);
                // return exp(-abs(depthDiff));
            }

            half SampleFogDepth(float2 uv)
            {
                return SAMPLE_DEPTH_TEXTURE(_FogDepthTexture, sampler_FogDepthTexture, uv);
            }

            half4 Filter(float2 uv, float2 TexelSize, half depthLinear)
            {
                half4 res;
                #if _FilterMode_Box4x4
					// Use a 4x4 box filter because the random texture is tiled 4x4
					res =  SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
					res += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + TexelSize * float2(2, 0));
					res += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + TexelSize * float2(0, 2));
					res += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + TexelSize * float2(2, 2));
					res *= 0.25;
                #else
                {
                    float2 uvR = uv + TexelSize * float2(1, 0);
                    float2 uvT = uv + TexelSize * float2(0, 1);
                    float2 uvRT = uv + TexelSize * float2(1, 1);
                    float2 uvLT = uv + TexelSize * float2(-1, 1);
                    float2 uvL = uv + TexelSize * float2(-1, 0);
                    float2 uvB = uv + TexelSize * float2(0, -1);
                    float2 uvRB = uv + TexelSize * float2(1, -1);
                    float2 uvLB = uv + TexelSize * float2(-1, -1);
                    half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                    half4 colorR = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvR);
                    half4 colorT = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvT);
                    half4 colorRT = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvRT);
                    half4 colorLT = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvLT);
                    half4 colorL = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvL);
                    half4 colorB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvB);
                    half4 colorRB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvRB);
                    half4 colorLB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvLB);

                    half W = 0.147761;
                    half WR = 0.118318;
                    half WT = 0.118318;
                    half WRT = 0.0947416;
                    half WLT = 0.0947416;
                    half WL = 0.118318;
                    half WB = 0.118318;
                    half WRB = 0.0947416;
                    half WLB = 0.0947416;
                    #if _FilterMode_Gaussian
                	{
	            	    res = (color *	 W +
		 						colorR *  WR +
		 						colorT *  WT +
		 						colorRT * WRT +
		 						colorLT * WLT +
		 						colorL *  WL +
		 						colorB *  WB +
		 						colorRB * WRB +
		 						colorLB * WLB);
                	}
                    #elif _FilterMode_Bilateral
                	{
	            	    WR *=  LuminanceDiff(color, colorR);
						WT *=  LuminanceDiff(color, colorT);
						WRT *= LuminanceDiff(color, colorRT);
						WLT *= LuminanceDiff(color, colorLT);
						WL *=  LuminanceDiff(color, colorL);
						WB *=  LuminanceDiff(color, colorB);
						WRB *= LuminanceDiff(color, colorRB);
						WLB *= LuminanceDiff(color, colorLB);
						res = (color   * W +
						 	   colorR  * WR +
						 	   colorT  * WT +
						 	   colorRT * WRT +
						 	   colorLT * WLT +
						 	   colorL  * WL +
						 	   colorB  * WB +
						 	   colorRB * WRB +
						 	   colorLB * WLB );
						res /= W + WR + WT + WRT + WLT + WL + WB + WRB + WLB;
                	}
                    #elif _FilterMode_Bilateral_DepthWeight
                	{
                		half depthCur = depthLinear;
	            	    half depthR  = LinearEyeDepth(SampleFogDepth(uvR), _ZBufferParams);
						half depthT  = LinearEyeDepth(SampleFogDepth(uvT), _ZBufferParams);
						half depthRT = LinearEyeDepth(SampleFogDepth(uvRT), _ZBufferParams);
						half depthLT = LinearEyeDepth(SampleFogDepth(uvLT), _ZBufferParams);
						half depthL  = LinearEyeDepth(SampleFogDepth(uvL), _ZBufferParams);
						half depthB  = LinearEyeDepth(SampleFogDepth(uvB), _ZBufferParams);
						half depthRB = LinearEyeDepth(SampleFogDepth(uvRB), _ZBufferParams);
						half depthLB = LinearEyeDepth(SampleFogDepth(uvLB), _ZBufferParams);
						WR  *= DepthWeight(depthR - depthCur);
						WT  *= DepthWeight(depthT - depthCur);
						WRT *= DepthWeight(depthRT - depthCur);
						WLT *= DepthWeight(depthLT - depthCur);
						WL  *= DepthWeight(depthL - depthCur);
						WB  *= DepthWeight(depthB - depthCur);
						WRB *= DepthWeight(depthRB - depthCur);
						WLB *= DepthWeight(depthLB - depthCur);
                		res = (color   * W +
						 	   colorR  * WR +
						 	   colorT  * WT +
						 	   colorRT * WRT +
						 	   colorLT * WLT +
						 	   colorL  * WL +
						 	   colorB  * WB +
						 	   colorRB * WRB +
						 	   colorLB * WLB );
						res /= W + WR + WT + WRT + WLT + WL + WB + WRB + WLB;
                	}
                    #else
                    {
                        res = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                    }
                    #endif
                }

                #endif
                return res;
            }

            float2 GetHistoryUV(float2 uv, float depth)
            {
                float4 curClip = ComputeClipSpacePosition3(uv, depth);
                float4 lastClip = mul(_ClipToLastClip, curClip);
                return (lastClip.xy / lastClip.w + 1.0) * 0.5;
            }

            half DepthClamp(float2 lastUV, float2 uv, half depthLinear)
            {
                #if _DepthClamp | _DepthClamp_Neighbor
                {
                	half lastDepth = SAMPLE_DEPTH_TEXTURE(_LastDepthTexture, sampler_LastDepthTexture, lastUV);
                	lastDepth = LinearEyeDepth(lastDepth, _ZBufferParams);
                	
            		//adjust depth due to camera movement
                	half movedDepth = dot(GetCameraPositionWS() - _LastCameraPos, _CameraForward);
                    half curDepth = max(depthLinear + movedDepth, 0);

                    DEBUG_OUTPUT(half4(abs(lastDepth - curDepth), 0, 0, 0), 1002001, "Athena/体积雾/深度差值");
            		half minDepth = min(curDepth, lastDepth);
                	
            		// threshold varies with distance
                	half dis01 = saturate(minDepth / _DepthClampMaxDistance);
                	half threshold = lerp(_DepthThresholdMin, _DepthThresholdMax, dis01);
                	
                
                	if (abs(lastDepth - curDepth) > threshold)
                	{
	                    return _DepthClampWeight;
                	}
                }
                #endif

                return 1;
            }

            #define _Reprojection 1

            half4 Fragment(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                half depth = SampleFogDepth(uv);
                half depthLinear = LinearEyeDepth(depth, _ZBufferParams);
                half4 col = Filter(uv, _MainTex_TexelSize.xy, depthLinear);
                if (_HistoryWeight > 0)
                {
                    half historyWeight = _HistoryWeight;
                    float2 lastUV = uv;
                    // reprojection is not always necessary, because you can not get the exact history value
                    #if _Reprojection
                    {
                        lastUV = GetHistoryUV(uv, depth);
                        if (any(lastUV > float2(1, 1)) || any(lastUV < float2(0, 0)))
                        {
                            historyWeight = 0;
                        }

                        // escape bilinear interpolation of history sampling
                        lastUV = (uint2(lastUV * _MainTex_TexelSize.zw) + 0.5) * _MainTex_TexelSize.xy;
                    }
                    #endif

                    half4 historyCol = SAMPLE_TEXTURE2D(_HistoryFogTexture, sampler_HistoryFogTexture, lastUV);
                    historyWeight *= DepthClamp(lastUV, uv, depthLinear);
                    col = lerp(col, historyCol, historyWeight);
                }
                DEBUG_OUTPUT(half4(col.rgb, 0), 1002009, "Athena/体积雾/体积雾最终");
                SHOW_DEBUG_OUTPUT_FRAGMENT_ONLY(ReconstructWorldPos(uv, depth))
                return col;
            }
            ENDHLSL
        }
    }
}