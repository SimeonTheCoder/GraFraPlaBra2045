Shader "Custom/TropicalWater"
{
    Properties
    {
        _ShallowColor  ("Shallow Color",  Color) = (0.15, 0.85, 0.9, 0.88)
        _DeepColor     ("Deep Color",     Color) = (0.02, 0.45, 0.75, 0.95)
        _FoamColor     ("Foam Color",     Color) = (0.9, 0.98, 1.0, 1.0)
        _FoamThreshold ("Foam Threshold", Range(0,1)) = 0.75
        _ShimmerSpeed  ("Shimmer Speed",  Float) = 1.2
        _ShimmerScale  ("Shimmer Scale",  Float) = 8.0
        _ShimmerStrength("Shimmer Strength", Range(0,1)) = 0.4
        _WaveSpeed     ("Wave Speed",     Float) = 0.25
        _WaveHeight    ("Wave Height",    Float) = 0.04
        _WaveFreq      ("Wave Frequency", Float) = 2.0
        _Tiling        ("Tiling",         Float) = 6.0
        _DepthFade     ("Depth Fade",     Float) = 0.5
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _ShallowColor;
                float4 _DeepColor;
                float4 _FoamColor;
                float  _FoamThreshold;
                float  _ShimmerSpeed;
                float  _ShimmerScale;
                float  _ShimmerStrength;
                float  _WaveSpeed;
                float  _WaveHeight;
                float  _WaveFreq;
                float  _Tiling;
                float  _DepthFade;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float2 uvRaw       : TEXCOORD1; // un-scrolled for foam
                float  vertexY     : TEXCOORD2;
            };

            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float smoothNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(
                    lerp(hash(i),               hash(i + float2(1,0)), f.x),
                    lerp(hash(i + float2(0,1)), hash(i + float2(1,1)), f.x),
                    f.y
                );
            }

            // Layered noise for more organic look
            float fbm(float2 p)
            {
                float v = 0.0;
                v += smoothNoise(p)       * 0.5;
                v += smoothNoise(p * 2.1) * 0.25;
                v += smoothNoise(p * 4.3) * 0.125;
                return v;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 pos = IN.positionOS.xyz;

                // Very subtle vertex waves — these Sonic games were nearly flat
                float wave1 = sin((pos.x * _WaveFreq) + _Time.y * _WaveSpeed) * _WaveHeight;
                float wave2 = sin((pos.z * _WaveFreq * 1.3) + _Time.y * _WaveSpeed * 0.9) * _WaveHeight * 0.6;
                float wave3 = sin((pos.x * 0.5 + pos.z * 0.8) + _Time.y * _WaveSpeed * 0.6) * _WaveHeight * 0.4;
                pos.y += wave1 + wave2 + wave3;

                OUT.positionHCS = TransformObjectToHClip(pos);
                OUT.uvRaw = IN.uv;

                // Two UV layers scrolling in slightly different directions
                OUT.uv = IN.uv * _Tiling + float2(
                    _Time.y * _WaveSpeed * 0.4,
                    _Time.y * _WaveSpeed * 0.25
                );

                OUT.vertexY = pos.y;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Base colour from layered noise — shallow/deep blend
                float n = fbm(IN.uv);
                half4 col = lerp(_DeepColor, _ShallowColor, n);

                // Directional shimmer streaks (the bright lines you see in Sonic)
                float2 shimUV = IN.uv * float2(0.5, _ShimmerScale) + float2(0, -_Time.y * _ShimmerSpeed);
                float shimmer = smoothstep(0.78, 0.88, sin(shimUV.y + sin(shimUV.x * 3.0) * 0.4));
                // Second layer of shimmers at different angle
                float2 shimUV2 = IN.uv * float2(0.4, _ShimmerScale * 1.3) + float2(_Time.y * 0.1, -_Time.y * _ShimmerSpeed * 0.7);
                float shimmer2 = smoothstep(0.82, 0.9, sin(shimUV2.y + sin(shimUV2.x * 2.0) * 0.5)) * 0.5;
                col.rgb += (shimmer + shimmer2) * _ShimmerStrength;

                // Foam — appears at wave crests (high vertex Y) and as a noise pattern near edges
                float foamNoise = fbm(IN.uvRaw * 8.0 + float2(_Time.y * 0.2, 0));
                float foamMask = step(_FoamThreshold, foamNoise);
                // Also foam at wave peaks
                float crestFoam = smoothstep(0.06, 0.12, IN.vertexY);
                float foam = saturate(foamMask * 0.4 + crestFoam * 0.8);
                col = lerp(col, _FoamColor, foam);

                return col;
            }
            ENDHLSL
        }
    }
}