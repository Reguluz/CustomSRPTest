#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "YostarPBRFunction.hlsl"




struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct YostarVaryings
{
    float2 uv                       : TEXCOORD0;
    float2 lightmapUV               : TEXCOORD1;
    half3  vertexSH                 : TEXCOORD2;

#ifdef _ADDITIONAL_LIGHTS
    float3 positionWS               : TEXCOORD3;
#endif

#ifdef _NORMALMAP
    float4 normalWS                 : TEXCOORD4;    // xyz: normal, w: viewDir.x
    float4 tangentWS                : TEXCOORD5;    // xyz: tangent, w: viewDir.y
    float4 bitangentWS              : TEXCOORD6;    // xyz: bitangent, w: viewDir.z
#else
    float3 normalWS                 : TEXCOORD4;
    float3 viewDirWS                : TEXCOORD5;
#endif

    half4 fogFactorAndVertexLight   : TEXCOORD7; // x: fogFactor, yzw: vertex light

#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD8;
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void YostarInitializeInputData(YostarVaryings input, half3 normalTS, out YostarInputData inputData)
{
    inputData = (YostarInputData)0;



#ifdef _ADDITIONAL_LIGHTS
    inputData.positionWS = input.positionWS;
#endif

#ifdef _NORMALMAP
    half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
    inputData.normalWS = TransformTangentToWorld(normalTS,
        half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
#else
    half3 viewDirWS = input.viewDirWS;
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    viewDirWS = SafeNormalize(viewDirWS);

    inputData.viewDirectionWS = viewDirWS;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    inputData.shadowCoord = input.shadowCoord;
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;

    inputData.Lightmap = SampleLightmap(input.lightmapUV,  inputData.normalWS);
    inputData.SH = SampleSHPixel(input.vertexSH, inputData.normalWS);
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
YostarVaryings YostarLitPassVertex(Attributes input)
{
    YostarVaryings output = (YostarVaryings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

#ifdef _NORMALMAP
    output.normalWS = half4(normalize(normalInput.normalWS), viewDirWS.x);
    output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
    output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
#else
    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    output.viewDirWS = viewDirWS;
#endif

    output.lightmapUV.xy = input.lightmapUV.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    output.vertexSH = SampleSHVertex(output.normalWS.xyz);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#ifdef _ADDITIONAL_LIGHTS
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// Used in Standard (Physically Based) shader
half4 YostarLitPassFragment(YostarVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);


    SurfaceData surfaceData;

    //PBRParams : metallic smoothness ao emission
//InitializeStandardLitSurfaceData(input.uv, surfaceData);
    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    surfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    half4 specGloss = SampleMetallicSpecGloss(input.uv, albedoAlpha.a);
    surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

#if _SPECULAR_SETUP
    surfaceData.metallic = 1.0h;
    surfaceData.specular = specGloss.rgb;
#else
    surfaceData.metallic = specGloss.r;
    surfaceData.specular = half3(0.0h, 0.0h, 0.0h);
#endif

    surfaceData.smoothness = specGloss.a;
    surfaceData.normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    surfaceData.occlusion = SampleOcclusion(input.uv);
    surfaceData.emission = SampleEmission(input.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    

//old
    // InputData inputData;
    // InitializeInputData(input, surfaceData.normalTS, inputData);
    // half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);

//New
    YostarInputData inputData;
    YostarInitializeInputData(input, surfaceData.normalTS, inputData);
    half4 color = YostarFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular,
    surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);


    return color;
}

#endif
