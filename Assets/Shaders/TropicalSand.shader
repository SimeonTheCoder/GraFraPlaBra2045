Shader "Custom/TropicalSand"
{
    Properties
    {
        _SandColor     ("Sand Color",      Color) = (0.96, 0.85, 0.58, 1.0)
        _SandDark      ("Sand Dark Color", Color) = (0.78, 0.65, 0.38, 1.0)
        _WetSand       ("Wet Sand Color",  Color) = (0.72, 0.60, 0.38, 1.0)
        _WetHeight     ("Wet Sand Height", Float) = 0.5
        _WetBlend      ("Wet Blend Soft",  Float) = 0.4
        _NoiseScale    ("Noise Scale",     Float) = 6.0
        _SunDir        ("Sun Direction",   Vector) = (0.5, 1.0, 0.5, 0)
        _SunColor      ("Sun Color",       Color) = (1.0, 0.92, 0.7, 1.0)
        _SunStrength   ("Sun Strength",    Range(0,1)) = 0.3
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _SandColor;
                float4 _SandDark;
                float4 _WetSand;
                float  _WetHeight;
                float  _WetBlend;
                float  _NoiseScale;
                float4 _SunDir;
                float4 _SunColor;
                float  _SunStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 positionWS  : TEXCOORD2;
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

            float fbm(float2 p)
            {
                float v = 0.0;
                v += smoothNoise(p)       * 0.5;
                v += smoothNoise(p * 2.3) * 0.25;
                v += smoothNoise(p * 5.1) * 0.125;
                return v;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv          = IN.uv;
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Noise-based sand colour variation
                float n = fbm(IN.uv * _NoiseScale);
                half4 col = lerp(_SandDark, _SandColor, n);

                // Wet sand near waterline (low world Y)
                float wetMask = 1.0 - smoothstep(
                    _WetHeight - _WetBlend,
                    _WetHeight + _WetBlend,
                    IN.positionWS.y
                );
                col = lerp(col, _WetSand, wetMask * 0.85);

                // Flat cel-style sun shading (no PBR)
                float3 sunDir = normalize(_SunDir.xyz);
                float NdotL = dot(normalize(IN.normalWS), sunDir);
                float cel = NdotL > 0.0 ? 1.0 : 0.6; // 2-step toon
                col.rgb *= cel;

                // Warm sun tint on lit faces
                col.rgb += _SunColor.rgb * saturate(NdotL) * _SunStrength;

                return col;
            }
            ENDHLSL
        }
    }
}