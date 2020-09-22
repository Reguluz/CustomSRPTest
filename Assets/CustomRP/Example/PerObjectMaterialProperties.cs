using UnityEngine;

public class PerObjectMaterialProperties : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");
	static int normalStrId = Shader.PropertyToID("_NormalStr");

	[SerializeField]
	public Color baseColor = Color.white;
	[Range(0,1)]public float normalStr = 0;

    static MaterialPropertyBlock block;

    void OnValidate () {
		if (block == null) {
			block = new MaterialPropertyBlock();
		}
		block.SetColor(baseColorId, baseColor);
		block.SetFloat(normalStrId, normalStr);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }
    
}
