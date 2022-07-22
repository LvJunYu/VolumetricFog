#if UNITY_EDITOR
using System.IO;
using UnityEditor;
#endif
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

/// <summary>
/// 生成高度图，自动配置材质参数，生成后可去掉
/// </summary>
public class HeightTexFetch : MonoBehaviour
{
    private const int MaxHeightTextureSize = 2048;
    public LayerMask layerMask = -1;
    public float meterPerPix = 1;
    [Min(0)] public int blurCount = 1;
    public Texture2D bakedHeightMap;

#if UNITY_EDITOR
    [ContextMenu("生成高度图")]
    public void BakeHeightTex()
    {
        var mat = GetComponent<MeshRenderer>().sharedMaterial;
        var path = AssetDatabase.GetAssetPath(mat);
        var extendName = Path.GetExtension(path);
        var center = transform.position;
        var transSize = transform.lossyScale / 2f;
        var height = transSize.y * 2f;
        var size = Mathf.Max(transSize.x, transSize.z);
        center.y += transSize.y;
        var texSize = Mathf.Min(MaxHeightTextureSize, Mathf.RoundToInt(size * 2f / meterPerPix));
        var depthCopyShader = Shader.Find("Hidden/VolumetricFog/HeightFetchCopyDepth");
        var savePath = path.Replace(extendName, "_HeightMap.png");
        bakedHeightMap = GetDepth(center, size, height, blurCount, layerMask, texSize, depthCopyShader,
            savePath);
        mat.SetTexture("_HeightMap", bakedHeightMap);
        // mat.SetVector("_HeightMapCenterRange", new Vector4(center.x, center.y, center.z, size));
        // mat.SetFloat("_HeightMapDepth", height);
    }
#endif

    public static Texture2D GetDepth(Vector3 pos, float orthographicSize, float maxDistance, int blurCount,
        LayerMask layerMask, int texSize, Shader depthCopyShader, string savePath)
    {
        //Generate the camera
        GameObject go = new GameObject("depthCamera"); //create the cameraObject
        // go.hideFlags = HideFlags.HideAndDontSave;
        var depthCam = go.AddComponent<Camera>();
        var cameraData = depthCam.GetComponent<UniversalAdditionalCameraData>();
        if (cameraData == null)
        {
            cameraData = depthCam.gameObject.AddComponent<UniversalAdditionalCameraData>();
        }

        cameraData.renderShadows = false;
        cameraData.requiresColorOption = CameraOverrideOption.Off;
        cameraData.requiresDepthOption = CameraOverrideOption.Off;
        // cameraData.SetRenderer(1);
        var transform1 = depthCam.transform;

        transform1.position = pos; //center the camera on this water plane
        transform1.up = Vector3.forward; //face teh camera down
        depthCam.enabled = true;
        depthCam.orthographic = true;
        depthCam.orthographicSize = orthographicSize; //hardcoded = 1k area - TODO
        //_depthCam.depthTextureMode = DepthTextureMode.Depth;
        depthCam.nearClipPlane = 0.01f;
        depthCam.farClipPlane = maxDistance;
        depthCam.allowHDR = false;
        depthCam.allowMSAA = false;
        depthCam.cullingMask = layerMask.value;

        //Generate RT
        var depthRT = RenderTexture.GetTemporary(texSize, texSize, 24, RenderTextureFormat.Depth,
            RenderTextureReadWrite.Linear);
        var tempTex1 =
            RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        var tempTex2 =
            RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.OpenGLES2 ||
            SystemInfo.graphicsDeviceType == GraphicsDeviceType.OpenGLES3)
        {
            tempTex2.filterMode = tempTex1.filterMode = depthRT.filterMode = FilterMode.Bilinear;
            tempTex2.wrapMode = tempTex1.wrapMode = depthRT.wrapMode = TextureWrapMode.Clamp;
        }

        //do depth capture
        depthCam.targetTexture = depthRT;
        depthCam.Render();

        var copyMat = new Material(depthCopyShader);
        Graphics.Blit(depthRT, tempTex1, copyMat, 0);
        for (int i = 0; i < blurCount; i++)
        {
            Graphics.Blit(tempTex1, tempTex2, copyMat, 1);
            Graphics.Blit(tempTex2, tempTex1, copyMat, 2);
        }

        depthCam.enabled = false;
        depthCam.targetTexture = null;
        var bakedDepthTex = new Texture2D(texSize, texSize, TextureFormat.RFloat, false, true);
        RenderTexture.active = tempTex1;
        bakedDepthTex.ReadPixels(new Rect(0, 0, texSize, texSize), 0, 0);
        bakedDepthTex.Apply();

        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(depthRT);
        RenderTexture.ReleaseTemporary(tempTex1);
        RenderTexture.ReleaseTemporary(tempTex2);
        SafeDestroy(copyMat);
        SafeDestroy(go);
#if UNITY_EDITOR
        // save depth tex to asset
        byte[] image = bakedDepthTex.EncodeToPNG();
        var path = savePath.Replace("Assets", Application.dataPath);
        var assetPath = savePath;
        File.WriteAllBytes(path, image);
        AssetDatabase.Refresh();
        TextureImporter importer = AssetImporter.GetAtPath(assetPath) as TextureImporter;
        TextureImporterSettings setting = new TextureImporterSettings();
        if (importer != null)
        {
            importer.ReadTextureSettings(setting);
            setting.textureType = TextureImporterType.SingleChannel;
            setting.singleChannelComponent = TextureImporterSingleChannelComponent.Red;
            setting.wrapMode = TextureWrapMode.Clamp;
            importer.SetTextureSettings(setting);
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.SaveAndReimport();
        }

        bakedDepthTex = AssetDatabase.LoadAssetAtPath<Texture2D>(assetPath);
        Debug.Log($"Bake height tex successfully, save in {assetPath}");
#endif
        return bakedDepthTex;
    }

    private static void SafeDestroy(Object o)
    {
        if (Application.isPlaying)
            Object.Destroy(o);
        else
            Object.DestroyImmediate(o);
    }
}