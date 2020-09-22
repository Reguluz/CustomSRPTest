using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class GlobalEnvironment : MonoBehaviour
{
    public Cubemap fakeGI;
    void OnValidate()
    {
        Shader.SetGlobalTexture("_GICubeMap", fakeGI);
    }
}
