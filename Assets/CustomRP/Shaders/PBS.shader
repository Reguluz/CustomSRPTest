Shader "Custom RP/PBS"
{
    Properties
    {
        _MainTex                ("Main Tex", 2D) = "white" {}
        _BaseColor              ("BaseColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _NormalTex              ("Normal Tex", 2D) = "Bump" {}
        _NormalStr              ("Normal Str", Range(0, 1)) = 1
        _PBRParams              ("PBRParams", 2D) = "black" {}
        [Toggle(_EMISSION)]_Emission("Emission", Float) = 0
        _Metallic               ("Metallic", Range(0, 1)) = 0
        _Specular               ("Specular", Range(0, 1)) = 0
        _Smoothness             ("Smoothness", Range(0, 1)) = 0.5
        _Cutoff                 ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
    }
    SubShader
    {
        Pass
        {
            Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
            Tags
            {
                "LightMode" = "CustomLit"
            }
            HLSLPROGRAM
            #pragma shader_feature _PREMULTIPLY_ALPHA
            #pragma shader_feature _RECEIVE_SHADOWS
			#pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
			#pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile_instancing
            #pragma vertex PBSPassVertex
			#pragma fragment PBSPassFragment
			
            #include "PBSPass.hlsl"
            ENDHLSL
        }
        
        Pass 
        {
			Tags 
			{
				"LightMode" = "ShadowCaster"
			}

			ColorMask 0

			HLSLPROGRAM
			#pragma target 3.5
			#pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma shader_feature _RECEIVE_SHADOWS
			#pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
		}
    }
    CustomEditor "CustomShaderGUI"
}
