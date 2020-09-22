using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    private const string bufferName = "Lighting";
    private CullingResults cullingResults;
    private Shadows shadows = new Shadows();
    private const int maxDirLightCount = 4;
    private const int maxPointDynamicLightCount = 8;
    private static int
        dirLightCountId = Shader.PropertyToID("_CustomLightCount"),
        dirLightColorsId = Shader.PropertyToID("_CustomLightColors"),
        dirLightDirectionsId = Shader.PropertyToID("_CustomDirOrPosRadius"),
        dirLightShadowDataId = Shader.PropertyToID("_CustomLightShadowData");
    static Vector4[] dirLightColors = new Vector4[maxDirLightCount],
        dirLightDirections = new Vector4[maxDirLightCount],
        dirLightShadowData = new Vector4[maxDirLightCount];
    private CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings shadowSettings)
    {
        this.cullingResults = cullingResults;
        buffer.BeginSample(bufferName);
        shadows.Setup(context, cullingResults, shadowSettings);
//        SetupDirectionalLight();
        SetupLights();
        shadows.Render();
        buffer.EndSample(bufferName);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    void SetupLights()
    {
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                if (dirLightCount >= maxDirLightCount)
                {
                    break;
                }
            }
            if(visibleLight.lightType == LightType.Point)
            {
                SetupPointLight(dirLightCount++, ref visibleLight);
                if (dirLightCount >= maxPointDynamicLightCount)
                {
                    break;
                }
            }
        }
        
        buffer.SetGlobalInt(dirLightCountId, visibleLights.Length);
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
        buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }
    
    void SetupDirectionalLight(int index, ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        dirLightShadowData[index] = shadows.ReserveDirectionalShadows(visibleLight.light, index);
    }

    void SetupPointLight(int index, ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = visibleLight.light.gameObject.transform.position;
        dirLightDirections[index].w = visibleLight.light.range;
        dirLightShadowData[index] = shadows.ReserveDirectionalShadows(visibleLight.light, index);
        Debug.Log(dirLightDirections[index]);
    }

    public void Cleanup () {
        shadows.Cleanup();
    }
    
}
