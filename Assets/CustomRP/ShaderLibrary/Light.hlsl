#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#include "Shadows.hlsl"

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_DYNAMIC_POINT_LIGHTS 8

CBUFFER_START(_CustomLight)
    int _CustomLightCount;
    float4 _CustomLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _CustomDirOrPosRadius[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _CustomLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END


struct Light{
    float3 color;
    float4 dirOrPosInvRadius;
    float attenuation;
};
int GetCustomLightCount(){
    return _CustomLightCount;
}

DirectionalShadowData GetCustomShadowData (int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	data.strength = _CustomLightShadowData[lightIndex].x * shadowData.strength;
	data.tileIndex = _CustomLightShadowData[lightIndex].y + shadowData.cascadeIndex;
	data.normalBias = _CustomLightShadowData[lightIndex].z;
	return data;
}

Light GetCustomLight(int index, Surface surfaceWS, ShadowData shadowData){
    Light light;
    light.color = _CustomLightColors[index].rgb;
    light.dirOrPosInvRadius = _CustomDirOrPosRadius[index];
    DirectionalShadowData dirShadowData = GetCustomShadowData(index, shadowData);
    light.attenuation = GetCustomShadowAttenuation(dirShadowData, shadowData, surfaceWS);
    //light.attenuation = shadowData.cascadeIndex * 0.25;
    return light;
}



#endif
