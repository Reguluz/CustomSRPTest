#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "UnityInput.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection


#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
/*
float3 TransformObjectToWorld(float3 positionOS)
{
    return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
}

float4 TransformWorldToHClip(float3 positionWS)
{
    return mul(unity_MatrixVP, float4(positionWS, 1.0));
}
*/
float DistanceSquared(float3 pA, float3 pB) {
	return dot(pA - pB, pA - pB);
}
half3 TangentToWorldNormal(float3 dir, float3x3 TBN)
{
    return normalize(TBN[0].xyz * dir.x + TBN[1].xyz * dir.y + TBN[2].xyz * dir.z);
}
// half3 UnpackNormal(half4 packednormal)
// {
//     // This do the trick
//    packednormal.x *= packednormal.w;

//     half3 normal;
//     normal.xy = packednormal.xy * 2 - 1;
//     normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
//     return normal;
// }
half3 GetNormal(half4 normTex, float3x3 TBN)
{
    half3 result = UnpackNormal(normTex);
    return TangentToWorldNormal(result, TBN);
}

half3 Luminance( half3 LinearColor )
{
	return dot( LinearColor, half3( 0.3, 0.59, 0.11 ) );
}
half3x3 MakeT2W(half3 normal, half4 tangent)
{
    half sign = tangent.w * unity_WorldTransformParams.w;
    half3 binormal = cross(normal, tangent) * sign;
    return half3x3(tangent.xyz, binormal, normal);
}

#endif