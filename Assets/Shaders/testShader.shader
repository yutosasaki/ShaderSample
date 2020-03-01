Shader "Custom/testShader"
{
     Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        _Hue ("Hue", Float) = 0
        _Sat ("Saturation", Float) = 1
        _Val ("Value", Float) = 1

        _HeightMap ("Heightmap (A)", 2D) = "black" {}
        _Height ("Height", Range (0.0, 1.0)) = 0.5
        _NormalMap ("Normalmap", 2D) = "bump" {}

        //_Luminance ("Luminance", Float) = 0
        _Threshold ("Threshold", Float) = 0.0
        
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200
        
        CGPROGRAM
        #include "UnityCG.cginc"
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input {
            float2 uv_MainTex;
            //float3 worldNormal;
            float3 viewDir;
            fixed luminance;
            float2 uv_NormalMap;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
        half _Hue, _Sat, _Val;
        float3 _UserWorldSpaceLightDir;
        float _Threshold; // 明度閾値
        sampler2D _HeightMap;
        float _Height;
        sampler2D _NormalMap;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
        // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)
        
        // RGB->HSV変換
        float3 rgb2hsv(float3 rgb)
        {
            float3 hsv;

            // RGBの三つの値で最大のもの
            float maxValue = max(rgb.r, max(rgb.g, rgb.b));
            // RGBの三つの値で最小のもの
            float minValue = min(rgb.r, min(rgb.g, rgb.b));
            // 最大値と最小値の差
            float delta = maxValue - minValue;
            
            // V（明度）
            // 一番強い色をV値にする
            hsv.z = maxValue;
            
            // S（彩度）
            // 最大値と最小値の差を正規化して求める
            if (maxValue != 0.0){
                hsv.y = delta / maxValue;
            } else {
                hsv.y = 0.0;
            }
            
            // H（色相）
            // RGBのうち最大値と最小値の差から求める
            if (hsv.y > 0.0){
                if (rgb.r == maxValue) {
                    hsv.x = (rgb.g - rgb.b) / delta;
                } else if (rgb.g == maxValue) {
                    hsv.x = 2 + (rgb.b - rgb.r) / delta;
                } else {
                    hsv.x = 4 + (rgb.r - rgb.g) / delta;
                }
                hsv.x /= 6.0;
                if (hsv.x < 0)
                {
                    hsv.x += 1.0;
                }
            }
            
            return hsv;
        }
        
        // HSV->RGB変換
        float3 hsv2rgb(float3 hsv)
        {
            float3 rgb;

            if (hsv.y == 0){
                // S（彩度）が0と等しいならば無色もしくは灰色
                rgb.r = rgb.g = rgb.b = hsv.z;
            } else {
                // 色環のH（色相）の位置とS（彩度）、V（明度）からRGB値を算出する
                hsv.x *= 6.0;
                float i = floor (hsv.x);
                float f = hsv.x - i;
                float aa = hsv.z * (1 - hsv.y);
                float bb = hsv.z * (1 - (hsv.y * f));
                float cc = hsv.z * (1 - (hsv.y * (1 - f)));
                if( i < 1 ) {
                    rgb.r = hsv.z;
                    rgb.g = cc;
                    rgb.b = aa;
                } else if( i < 2 ) {
                    rgb.r = bb;
                    rgb.g = hsv.z;
                    rgb.b = aa;
                } else if( i < 3 ) {
                    rgb.r = aa;
                    rgb.g = hsv.z;
                    rgb.b = cc;
                } else if( i < 4 ) {
                    rgb.r = aa;
                    rgb.g = bb;
                    rgb.b = hsv.z;
                } else if( i < 5 ) {
                    rgb.r = cc;
                    rgb.g = aa;
                    rgb.b = hsv.z;
                } else {
                    rgb.r = hsv.z;
                    rgb.g = aa;
                    rgb.b = bb;
                }
            }
            return rgb;
        }
        
        float3 shift_col(float3 rgb, half3 shift)
        {
            // RGB->HSV変換
            float3 hsv = rgb2hsv(rgb);
            
            // HSV操作
            hsv.x += shift.x;
            if (1.0 <= hsv.x)
            {
                hsv.x -= 1.0;
            }
            hsv.y *= shift.y;
            hsv.z *= shift.z;
            
            // HSV->RGB変換
            return hsv2rgb(hsv);
        }

        // 明度を返す
        half getBrightness(half3 color){
            return max(color.r, max(color.g, color.b));
        }

        void vert(inout appdata_full v, out Input o) {
            // height map
            float d = tex2Dlod(_HeightMap, float4(v.texcoord.xy,0,0)).a * _Height;
            v.vertex.xyz += d.r;

            // 輝度計算
            UNITY_INITIALIZE_OUTPUT(Input, o);
            float4 invLightDir = mul(UNITY_MATRIX_M, WorldSpaceLightDir(v.vertex));
            // 各頂点の拡散反射輝度を算出 
            float luminance = dot(v.normal, normalize(invLightDir));
            o.luminance = luminance;
        }

        void surf (Input IN, inout SurfaceOutputStandard o) { 
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            half3 shift = half3(_Hue * IN.luminance * 0.1f, _Sat * IN.luminance, _Val * IN.luminance);

            //half brightness = getBrightness(c.rgb);  
            // 明度がThresholdより大きいピクセルだけブルームの対象とする
            //half contribution = max(0, brightness - _Threshold);
            //contribution /= max(brightness, 0.00001);

            fixed4 shiftColor = fixed4(shift_col(c.rgb, shift), c.a);
            o.Albedo = shiftColor.rgb * IN.luminance;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = shiftColor.a;
            o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
        }
       
        ENDCG
        }
    FallBack "Diffuse"
}