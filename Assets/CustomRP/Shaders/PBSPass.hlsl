#ifndef CUSTOM_PBS_INCLUDED
#define CUSTOM_PBS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"


TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
TEXTURE2D(_NormalTex);
SAMPLER(sampler_NormalTex);
TEXTURE2D(_PBRParams);
SAMPLER(sampler_PBRParams);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _NormalTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	UNITY_DEFINE_INSTANCED_PROP(float, _Specular)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _NormalStr)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)



struct Attributes{
    float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float4 tangentOS : TANGENT;
	float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float3 normalWS : TEXCOORD0;
	float2 baseUV : TEXCOORD1;
	float3x3 TBN : TEXCOORD2;
	float3 positionWS : TEXCOORD5;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings PBSPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    #if UNITY_REVERSED_Z
		output.positionCS.z =
			min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
	#else
		output.positionCS.z =
			max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
	#endif
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	output.TBN = CreateTangentToWorld(input.normalOS, input.tangentOS.xyz, input.tangentOS.w);
	output.TBN = MakeT2W(input.normalOS, input.tangentOS);
	// output.normalWS = input.normalOS;
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
	output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    return output;
}
float4 PBSPassFragment(Varyings input) : SV_TARGET
{

    UNITY_SETUP_INSTANCE_ID(input);
    float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	float4 base = baseMap * baseColor;
	#if defined(_SHADOWS_CLIP)
		clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
	#elif defined(_SHADOWS_DITHER)
		float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
		clip(base.a - dither);
	#endif
	float4 PBRParams = SAMPLE_TEXTURE2D(_PBRParams, sampler_PBRParams, input.baseUV);
	Surface surface;
	surface.position = input.positionWS;
	surface.normal = TransformObjectToWorldNormal(TransformTangentToObject(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, input.baseUV) , input.TBN));
	// surface.normal = (SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, input.baseUV) * 2 - 1);

	surface.normal = lerp(input.normalWS, surface.normal, UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _NormalStr));
	// return float4(surface.normal, 1);
	
	surface.color = base.rgb;
	surface.alpha = base.a;
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS).xyz;
	surface.depth = -TransformWorldToView(input.positionWS).z;
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
	surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic) * PBRParams.r;
	surface.specular = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Specular);
	surface.smoothness =
		UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness) * PBRParams.g;
	BRDF brdf = GetBRDF(surface, PBRParams);

		// float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
		// 	brdf.diffuse = surface.color * oneMinusReflectivity;

		// half DielectricSpecular = 0.08 * surface.specular;
		// 	brdf.specular = DielectricSpecular * oneMinusReflectivity + surface.color * surface.metallic;	

		// half NdV = max( dot( surface.normal, surface.viewDirection ), 0 );

		// 	float perceptualRoughness =
		// 		PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
		// 	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

		// brdf.specular = EnvBRDFApprox(brdf.specular, brdf.roughness, NdV);
		// //specular *= ImageBasedReflectionLighting;    ---->Environment Reflection
		// brdf.ao = PBRParams.b;
		// brdf.emission = PBRParams.a;

#if _EMISSION

#else
	brdf.emission = 0;
#endif
	float3 color = GetLightingBRDF(surface, brdf);

	return float4(color, 1);
}

#endif