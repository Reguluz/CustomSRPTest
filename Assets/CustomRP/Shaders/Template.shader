Shader "Custom RP/Template"
{
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex TemplateVertex
            #pragma fragment TemplateFragment

            #include "Template.hlsl"
            ENDHLSL
        }
    }
}
