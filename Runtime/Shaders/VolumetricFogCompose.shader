Shader "Hidden/VolumetricFog/Compose"
{
    Properties
    {
        [MainTexture] _MainTex("MainTex", 2D) = "white" {}
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
            Blend One SrcAlpha

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile _ DepthWeightedUpscale

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_LinearClamp);
            SAMPLER(sampler_PointClamp);
            float4 _MainTex_TexelSize;
            TEXTURE2D_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }


            // #define DepthWeightedUpscale 1
            
            half DepthWeight(float depthDiff)
            {
            	return 1 / (depthDiff * depthDiff + 1);
	            // return exp(-abs(depthDiff));
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                #if DepthWeightedUpscale
	                float2 pix = input.uv * _MainTex_TexelSize.zw;
                    int2 pixCenter = int2(pix + 0.5);
                    float2 uvLB = (pixCenter + float2(-0.5, -0.5));
                    float2 uvRB = (pixCenter + float2(0.5, -0.5));
                    float2 uvLT = (pixCenter + float2(-0.5, 0.5));
                    float2 uvRT = (pixCenter + float2(0.5, 0.5));
                    half weightX = pix.x - uvLB.x;
                    half weightY = pix.y - uvLB.y;
                    uvLB *= _MainTex_TexelSize.xy;
                    uvRB *= _MainTex_TexelSize.xy;
                    uvLT *= _MainTex_TexelSize.xy;
                    uvRT *= _MainTex_TexelSize.xy;
                    half4 colLB = SAMPLE_TEXTURE2D(_MainTex, sampler_PointClamp, uvLB);
                    half4 colRB = SAMPLE_TEXTURE2D(_MainTex, sampler_PointClamp, uvRB);
                    half4 colLT = SAMPLE_TEXTURE2D(_MainTex, sampler_PointClamp, uvLT);
                    half4 colRT = SAMPLE_TEXTURE2D(_MainTex, sampler_PointClamp, uvRT);

                    //half4 colB = lerp(colLB, colRB, weightX);
                    //half4 colT = lerp(colLT, colRT, weightX);
                    half weightLB = (1 - weightX) * (1 - weightY);
                    half weightRB = weightX * (1 - weightY);
                    half weightLT = (1 - weightX) * weightY;
                    half weightRT = weightX * weightY;
                
                    float depthLinear  = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv), _ZBufferParams);
	                float depthLB  = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvLB), _ZBufferParams);
	                float depthRB  = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvRB), _ZBufferParams);
	                float depthLT  = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvLT), _ZBufferParams);
	                float depthRT  = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvRT), _ZBufferParams);
                    weightLB  *= max(0.0001, DepthWeight(depthLB - depthLinear));
                    weightRB  *= max(0.0001, DepthWeight(depthRB - depthLinear));
                    weightLT  *= max(0.0001, DepthWeight(depthLT - depthLinear));
                    weightRT  *= max(0.0001, DepthWeight(depthRT - depthLinear));
                
                    half4 col = colLB * weightLB + colRB * weightRB + colLT * weightLT + colRT * weightRT;
                    col /= weightLB + weightRB + weightLT + weightRT;
                #else
                    half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_LinearClamp, input.uv);
                #endif
                return col;
            }
            ENDHLSL
        }
    }
}