using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.VersionControl;
using UnityEngine;

public class NewBehaviourScript
{
   [MenuItem("Assets/Create CGIncludes")]
   static void CreateCGIncludes()
   {
      var path = "";
      var obj = Selection.activeObject;
      if (obj == null)
      {
         path = "Assets";
      }
      else
      {
         path = AssetDatabase.GetAssetPath(obj.GetInstanceID());
      }
      
      System.IO.FileStream sw = null;//流信息
      FileInfo t = new FileInfo ( path+ "//" + "NewCGIncludes"+".cginc");
      if (!t.Exists) {//判断文件是否存在
         sw = new FileStream(path+ "//" + "NewCGIncludes"+".cginc", System.IO.FileMode.Create);
      } else
      {
         LoopCreateCGIncludes(1, path);
         return;
      }
      sw.Close ();//关闭流
      sw.Dispose ();//销毁流
      AssetDatabase.Refresh();
   }
   
   static void LoopCreateCGIncludes(int serial, string path)
   {
      StreamWriter sw = null;
      FileInfo t = new FileInfo ( path+ "//" + "NewCGIncludes"+serial+".cginc");
      if (!t.Exists) 
      {
         sw = t.CreateText ();
      } else
      {
         LoopCreateCGIncludes(serial + 1, path);
         return;
      }
      sw.Close ();
      sw.Dispose ();
      AssetDatabase.Refresh();
      
   }
   
   [MenuItem("Assets/Create HLSLIncludes")]
   static void CreateHLSLIncludes()
   {
      var path = "";
      var obj = Selection.activeObject;
      if (obj == null)
      {
         path = "Assets";
      }
      else
      {
         path = AssetDatabase.GetAssetPath(obj.GetInstanceID());
      }
      
      StreamWriter sw = null;
      FileInfo t = new FileInfo ( path+ "//" + "NewHLSLIncludes"+".hlsl");
      if (!t.Exists) {
         sw = t.CreateText ();
      } else
      {
         LoopCreateHLSLIncludes(1, path);
         return;
      }
      sw.Write(GetTemplateHLSLIncludes());
      sw.Close ();
      sw.Dispose ();
      AssetDatabase.Refresh();
   }
   
   static void LoopCreateHLSLIncludes(int serial, string path)
   {
      StreamWriter sw = null;
      FileInfo t = new FileInfo ( path+ "//" + "NewHLSLIncludes"+serial+".hlsl");
      if (!t.Exists) {
         sw = t.CreateText ();
      } else
      {
         LoopCreateHLSLIncludes(serial + 1, path);
         return;
      }
      sw.Close ();
      sw.Dispose ();
      AssetDatabase.Refresh();
   }

   static string GetTemplateHLSLIncludes()
   {
      string template = "";
      template += "#ifndef CUSTOM_TEMPLATE_INCLUDED\n"+
                  "#define CUSTOM_TEMPLATE_INCLUDED\n";
      template += "#include \"../ShaderLibrary/Common.hlsl\"\n" +
                  "\n";
      template += "TEXTURE2D(_MainTex);\n";
      template += "SAMPLER(sampler_MainTex);\n" +
                  "\n";
      template += "UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)\n";
      template += "   UNITY_DEFINE_INSTANCED_PROP(float, _MainTex_ST)\n";
      template += "   UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)\n";
      template += "UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)\n" +
                  "\n";
      template += "struct Attributes{\n" +
                  "   float3 positionOS : POSITION;\n" +
                  "   float2 baseUV : TEXCOORD0;\n" +
                  "   UNITY_VERTEX_INPUT_INSTANCE_ID\n" +
                  "};\n";
      template += "struct Varyings {\n" +
                  "   float4 positionCS : SV_POSITION;\n" +
                  "   float2 baseUV : VAR_BASE_UV;\n" +
                  "   UNITY_VERTEX_INPUT_INSTANCE_ID\n" +
                  "};\n";
      template += "Varyings TemplateVertex(Attributes input)\n" +
                  "{"+
                  "   Varyings output;\n" +
                  "   UNITY_SETUP_INSTANCE_ID(input);\n" +
                  "   UNITY_TRANSFER_INSTANCE_ID(input, output);\n" +
                  "   float3 positionWS = TransformObjectToWorld(input.positionOS);\n" +
                  "   output.positionCS = TransformWorldToHClip(positionWS);\n" +
                  "   float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);\n" +
                  "   output.baseUV = input.baseUV * baseST.xy + baseST.zw;\n" +
                  "   return output;\n" +
                  "}\n";
      template += "float4 TemplateFragment(Varyings input) : SV_TARGET\n" +
                  "{\n" +
                  "   UNITY_SETUP_INSTANCE_ID(input);\n" +
                  "   float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.baseUV);\n" +
                  "   float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);\n" +
                  "   return baseMap * baseColor;\n" +
                  "}\n";
      template += "#endif";
      return template;
   }
}
