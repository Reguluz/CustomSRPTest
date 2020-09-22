#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#include "Shadows.hlsl"
#include "BRDF.hlsl"

TEXTURECUBE(_GICubeMap);
SAMPLER(sampler_GICubeMap);
TEXTURE2D(_LightMap);
SAMPLER(sampler_LightMap);

float RadialAttenuation(float3 WorldLightVector, half FalloffExponent)
{
	float NormalizeDistanceSquared = dot(WorldLightVector, WorldLightVector);

	// UE3 (fast, but now we not use the default of 2 which looks quite bad):
	return pow(1.0f - saturate(NormalizeDistanceSquared), FalloffExponent); 

	// new UE4 (more physically correct but slower and has a more noticable cutoff ring in the dark):
	// AttenFunc(x) = 1 / (x * x + 1)
	// derived: InvAttenFunc(y) = sqrtf(1 / y - 1)
	// FalloffExponent is ignored
	// the following code is a normalized (scaled and biased f(0)=1 f(1)=0) and optimized
/*
	// light less than x % is considered 0
	// 20% produces a bright sphere, 5 % is ok for performance, 8% looks close to the old one, smaller numbers would be more realistic but then the attenuation radius also should be increased.
	// we can expose CutoffPercentage later, alternatively we also can compute the attenuation radius from the CutoffPercentage and the brightness
	const float CutoffPercentage = 5.0f;  
	    
	float CutoffFraction = CutoffPercentage * 0.01f;  

	// those could be computed on C++ side
	float PreCompX = 1.0f - CutoffFraction;
	float PreCompY = CutoffFraction;
	float PreCompZ = CutoffFraction / PreCompX;

	return (1 / ( NormalizeDistanceSquared * PreCompX + PreCompY) - 1) * PreCompZ;
*/
}

float3 IncomingDirectionalLight (Surface surface, Light light) {
    //temp  
    // return dot(surface.normal, light.dirOrPosInvRadius)+1;
    // return light.attenuation;
	return saturate(dot(surface.normal, light.dirOrPosInvRadius.xyz) * light.attenuation) * light.color;
}
float3 IncomingPointLight (Surface surface, Light light, float3 ToLight) {
    //temp  
    // return dot(surface.normal, light.dirOrPosInvRadius)+1;
    // return light.attenuation;
	return saturate(dot(surface.normal, ToLight) * light.attenuation * light.dirOrPosInvRadius.w) * light.color;
}
float3 GetCustomDirectionalLightingBRDF (Surface surface, BRDF brdf, Light light) {
    //return IncomingLight(surface, light);
    half3 H = normalize(surface.viewDirection + light.dirOrPosInvRadius.xyz);
    half NdH = max(0, dot(surface.normal, H));
	return IncomingDirectionalLight(surface, light) * (brdf.diffuse + brdf.specular * CalcSpecular(brdf.roughness, NdH, H, surface.normal));
}

float3 GetCustomPointLightingBRDF (Surface surface, BRDF brdf, Light light) {
    //return IncomingLight(surface, light);
    float3 ToLight = light.dirOrPosInvRadius.xyz - surface.position;
    float DistanceSqr = dot(ToLight, ToLight);
    float3 L = ToLight * rsqrt(DistanceSqr);
    float3 H = normalize(surface.viewDirection + L);

    float NdL = max(0, dot(surface.normal, L));
    // float PointRoL = max(0, dot(MaterialParameters.ReflectionVector, L));
    float NdH = max(0, dot(surface.normal, H));

    float Attenuation = 1 / ( DistanceSqr + 1 );
    float InvRadius = 1 / light.dirOrPosInvRadius.w;
    Attenuation *= pow(saturate(1 - pow(DistanceSqr * (InvRadius * InvRadius),2)),2);		
	return (Attenuation * NdL) * light.color.rgb * brdf.diffuse;
}
float3 GetLighting (Surface surface, Light light) {
    //return IncomingLight(surface, light);
	return IncomingDirectionalLight(surface, light) * surface.color;
}
float3 GetLighting (Surface surfaceWS) {
    ShadowData shadowData = GetCustomShadowData(surfaceWS);
    float3 color = 0.0;
    for(int i = 0; i < GetCustomLightCount(); i++){
        Light light = GetCustomLight(i, surfaceWS, shadowData);
        color += GetLighting(surfaceWS, light);
    }
	return color;
}
float3 GetLightingBRDF (Surface surfaceWS, BRDF brdf) {
    ShadowData shadowData = GetCustomShadowData(surfaceWS);
    float3 color = 0.0;
    half IndirectIrradiance = 1;
    //color += lightmap * diff
    half3 DiffuseGI = SAMPLE_TEXTURECUBE_LOD(_GICubeMap, sampler_GICubeMap, surfaceWS.normal, 9);            //临时的
    IndirectIrradiance = Luminance(DiffuseGI);
    color += brdf.diffuse * DiffuseGI;
    color *= brdf.ao;
    IndirectIrradiance *= brdf.ao;
    //Color += SpecularIBL * SpecularColor
    for(int i = 0; i < GetCustomLightCount(); i++){
        Light light = GetCustomLight(i, surfaceWS, shadowData);
        if(light.dirOrPosInvRadius.w !=0)
        {
            color += GetCustomPointLightingBRDF(surfaceWS, brdf, light);
        }
        else
        {
            color += GetCustomDirectionalLightingBRDF(surfaceWS, brdf, light);
        }
    }
    color += brdf.emission;
	return color;
}



//float3 GetIncomingLight (Surface surface, Light light) {
//	return dot(surface.normal, light.dirOrPosInvRadius) * light.color;
//}

#endif
