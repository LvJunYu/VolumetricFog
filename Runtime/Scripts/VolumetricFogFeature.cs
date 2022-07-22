using System;
using System.Collections.Generic;
#if UNITY_EDITOR
using UnityEditor;
#endif
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

public class VolumetricFogFeature : ScriptableRendererFeature
{
    [Serializable]
    public class VolumetricFogSetting
    {
        public bool enable = true;

        [Header("分辨率缩放，效果可接受范围内越低越好")] [Range(0.01f, 1f)]
        public float scale = 0.6f; // 这里降采样倍数如果是0.5或者0.25会有噪点的鬼影
        // 猜测是深度图没有降采样导致采的深度不准确（正好采在两个像素中间）
        // 通过采相邻像素可以解决，另外改降采样倍数也可以

        [Range(2, 256)] public int stepCount = 8; // 步进次数，目前shader里写死了
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingTransparents;

        [Header("根据深度升采样降低Bleeding")] public bool depthWeightedUpscale = true;

        [Header("是否启用Spacial Filter")] public bool spatialFilter = true;
        public EFilterMode spatialFilterMode = EFilterMode.BilateralDepthWeighted;

        public Texture2D noiseTexture;

        // public Texture2D[] noiseTextures;
        [HideInInspector] [Range(0f, 2f)] public float noiseScale = 1f;
        [Header("是否启用Temporal Filter")] public bool temporalFilter = true;

        [HideInInspector] [Range(0f, 1f)] public float jitterScale = 1f;

        // [Min(2)] public int jitterSequence = 2;
        [Range(0f, 1f)] public float historyWeight = 0.91f;

        // [Header("鬼影优化：对比上一帧深度，如果差异过大则降低混合权重")] 
        public bool depthClampEnable = true;
        [Range(0f, 10f)] public float depthClampThresholdMin = 0.2f;
        [Range(0f, 10f)] public float depthClampThresholdMax = 2;

        [Min(0)] public float depthClampMaxDistance = 30f;

        // public bool depthClampSpread;
        [Range(0f, 1f)] public float depthClampWeight;

        [Header("鬼影优化：降低相机移动时的鬼影，但可能增加相机移动时的噪点")] [Range(0f, 1f)]
        public float cameraGhostAdjust = 0.5f;

        [Min(0)] public float cameraMoveWeight = 3f;
        [Min(0)] public float cameraRotateWeight = 0.5f;

        // [HideInInspector] [Header("提高步进次数")] public bool highQuality;

        [Header("Shaders")] public Shader filterShader;
        public Shader composeShader;
    }

    public enum EFilterMode
    {
        Point,
        Gaussian,
        Bilateral,
        BilateralDepthWeighted,
        Box4X4,
    }

    public VolumetricFogSetting settings = new VolumetricFogSetting();

    private VolumetricFogPass _volumetricFogPass;

    public override void Create()
    {
        if (settings.filterShader == null)
            settings.filterShader = Shader.Find("Hidden/VolumetricFog/Filter");
        if (settings.composeShader == null)
            settings.composeShader = Shader.Find("Hidden/VolumetricFog/Compose");
#if UNITY_EDITOR
        if (settings.noiseTexture == null)
            settings.noiseTexture =
                AssetDatabase.LoadAssetAtPath<Texture2D>(
                    "Packages/volumetric-fog/Runtime/Textures/BlueNoise.TGA");
#endif
        _volumetricFogPass?.Dispose();
        _volumetricFogPass = new VolumetricFogPass();
    }

    public static void SafeDestroy(Object o)
    {
        if (o == null) return;
        if (Application.isPlaying)
            Destroy(o);
        else
            DestroyImmediate(o);
    }

    private void OnDestroy()
    {
        _volumetricFogPass?.Dispose();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!settings.enable) return;
        _volumetricFogPass.Setup(settings, renderer);
        renderer.EnqueuePass(_volumetricFogPass);
    }
}

public class VolumetricFogPass : ScriptableRenderPass
{
    const string profilerTag = "VolumetricFogPass";
    ShaderTagId _shaderTagId = new ShaderTagId("VolumetricFog");
    ProfilingSampler _profilingSampler = new ProfilingSampler(profilerTag);
    FilteringSettings _filteringSettings = new FilteringSettings(RenderQueueRange.transparent);
    RenderTargetHandle _fogRT;
    RenderTargetHandle _depthRT;
    ScriptableRenderer _renderer;
    VolumetricFogFeature.VolumetricFogSetting _settings;
    private PerCameraDataManager<FogCameraData> _perCameraDataManager = new PerCameraDataManager<FogCameraData>();

    private class FogCameraData : IDisposable
    {
        public RenderTexture[] colorRTs = new RenderTexture[2];
        public RenderTexture[] depthRTs = new RenderTexture[2];
        public RenderTargetIdentifier[] colorTargets = new RenderTargetIdentifier[2];

        public int curRtIndex = -1;

        public Matrix4x4 lastViewProj;
        public Vector3 lastCameraPos;
        public Vector3 lastCameraForward;
        public bool hasHistoryRT;
        public int frameCount;
        public Material composeMaterial;
        public Material filterMaterial;

        public void CreateMaterials(VolumetricFogFeature.VolumetricFogSetting setting)
        {
            if (composeMaterial == null)
                composeMaterial = new Material(setting.composeShader);
            if (filterMaterial == null)
                filterMaterial = new Material(setting.filterShader);
        }

        private void DestroyMaterials()
        {
            if (composeMaterial != null)
                VolumetricFogFeature.SafeDestroy(composeMaterial);
            if (filterMaterial != null)
                VolumetricFogFeature.SafeDestroy(filterMaterial);
        }

        public void Dispose()
        {
            DestroyMaterials();
            for (var i = 0; i < colorRTs.Length; i++)
            {
                if (colorRTs[i] != null)
                {
                    RenderTexture.ReleaseTemporary(colorRTs[i]);
                    colorRTs[i] = null;
                }
            }

            for (var i = 0; i < depthRTs.Length; i++)
            {
                if (depthRTs[i] != null)
                {
                    RenderTexture.ReleaseTemporary(depthRTs[i]);
                    depthRTs[i] = null;
                }
            }

            curRtIndex = -1;
            hasHistoryRT = false;
            frameCount = 0;
        }
    }

    public VolumetricFogPass()
    {
        renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        _fogRT.Init("FogTexture");
        _depthRT.Init("UselessDepth"); // unity throw error if don't set depth attachment
    }

    public void Setup(VolumetricFogFeature.VolumetricFogSetting setting, ScriptableRenderer renderer)
    {
        _settings = setting;
        _renderer = renderer;
        renderPassEvent = setting.Event;
#if UNITY_2020_1_OR_NEWER
        ConfigureInput(ScriptableRenderPassInput.Depth);
#endif
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        ConfigureColorTextureDesc(ref cameraTextureDescriptor, RenderTextureFormat.ARGB32);
        cmd.GetTemporaryRT(_fogRT.id, cameraTextureDescriptor, FilterMode.Point);
        cameraTextureDescriptor.colorFormat = RenderTextureFormat.Depth;
        cameraTextureDescriptor.depthBufferBits = 16;
        cmd.GetTemporaryRT(_depthRT.id, cameraTextureDescriptor, FilterMode.Point);
        // ConfigureTarget(_colorTargets, _depthRT.Identifier());
        // ConfigureClear(ClearFlag.Color, Color.black);
    }

    private RenderTexture GetRenderTexture(string name, ref RenderTextureDescriptor descriptor, FilterMode filter,
        RenderTexture rt, out bool createNew)
    {
        createNew = false;
        if (rt != null)
        {
            if (rt.width != descriptor.width || rt.height != descriptor.height || rt.filterMode != filter)
            {
                RenderTexture.ReleaseTemporary(rt);
                rt = null;
            }
        }

        if (rt == null)
        {
            rt = RenderTexture.GetTemporary(descriptor);
            rt.filterMode = filter;
            rt.name = name;
            createNew = true;
        }

        return rt;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
#if UNITY_2020_1_OR_NEWER
        CommandBuffer cmd = CommandBufferPool.Get();
#else
        CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
#endif
        using (new ProfilingScope(cmd, _profilingSampler))
        {
            var data = _perCameraDataManager.GetOrAddData(renderingData.cameraData.camera);
            Prepare(ref renderingData, cmd, data);
            DoRayMarchingPass(context, cmd, data, ref renderingData);
            DoFilterPass(cmd, data, ref renderingData.cameraData);
            DoComposePass(cmd, data);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    private void Prepare(ref RenderingData renderingData, CommandBuffer cmd, FogCameraData fogData)
    {
        fogData.CreateMaterials(_settings);
        var cameraData = renderingData.cameraData;
        RenderTextureDescriptor descriptor = cameraData.cameraTargetDescriptor;

        // cmd.GetTemporaryRT(_fogRT.id, descriptor, FilterMode.Point);
        var colorRTs = fogData.colorRTs;
        var depthRTs = fogData.depthRTs;
        if (fogData.curRtIndex == -1)
        {
            fogData.curRtIndex = 0;
            fogData.hasHistoryRT = false;
        }

        var curIndex = fogData.curRtIndex;
        ConfigureColorTextureDesc(ref descriptor, RenderTextureFormat.ARGBHalf);
        colorRTs[curIndex] = GetRenderTexture(FogTexNames[curIndex], ref descriptor,
            _settings.scale < 1 && !_settings.depthWeightedUpscale ? FilterMode.Bilinear : FilterMode.Point,
            colorRTs[curIndex], out _);
        cmd.SetGlobalVector(FogTextureSize, new Vector4(descriptor.width, descriptor.height));

        descriptor.colorFormat = RenderTextureFormat.RFloat;
        depthRTs[curIndex] = GetRenderTexture(FogDepthTexNames[curIndex], ref descriptor, FilterMode.Point,
            depthRTs[curIndex], out _);

        fogData.colorTargets[0] = _fogRT.Identifier();
        fogData.colorTargets[1] = depthRTs[curIndex];

        // Unity提供的VP逆矩阵在不同版本处理不同，这里自己传入
        Matrix4x4 projMatrix = GL.GetGPUProjectionMatrix(cameraData.GetProjectionMatrix(), false);
        Matrix4x4 viewMatrix = cameraData.GetViewMatrix();
        Matrix4x4 viewProjMatrix = projMatrix * viewMatrix;
        Matrix4x4 invViewProjMatrix = Matrix4x4.Inverse(viewProjMatrix);
        cmd.SetGlobalMatrix(MyInvViewProjMatrix, invViewProjMatrix);
    }

    private void DoRayMarchingPass(ScriptableRenderContext context, CommandBuffer cmd, FogCameraData fogData,
        ref RenderingData renderingData)
    {
        DrawingSettings drawingSettings =
            CreateDrawingSettings(_shaderTagId, ref renderingData, SortingCriteria.CommonTransparent);
        if (_settings.spatialFilter)
        {
            Shader.EnableKeyword("_NoiseEnable");
            var noiseTex = _settings.noiseTexture;
            // if (_settings.noiseTextures.Length > 0)
            //     noiseTex = _settings.noiseTextures[Time.frameCount % _settings.noiseTextures.Length];
            cmd.SetGlobalTexture(NoiseMap, noiseTex);
            if (noiseTex != null)
                cmd.SetGlobalVector(NoiseMapTexelSize, new Vector4(noiseTex.width, noiseTex.height));
        }
        else
            Shader.DisableKeyword("_NoiseEnable");

        // if (_settings.highQuality)
        //     Shader.EnableKeyword("_HighQuality");
        // else
        //     Shader.DisableKeyword("_HighQuality");
        
        var transform = renderingData.cameraData.camera.transform;
        var currentCameraPos = transform.position;
        var currentCameraForward = transform.forward;
        var cameraMoveScale = CalculateCameraMoveScale(fogData.lastCameraPos, fogData.lastCameraForward,
            currentCameraPos, currentCameraForward);
        
        cmd.SetGlobalFloat("_CameraMoveScale", 1- cameraMoveScale);
        var jitter = _settings.temporalFilter
            ? Halton(fogData.frameCount++) * _settings.jitterScale
            : 1;
        cmd.SetGlobalVector(FogParam,
            new Vector4(jitter, _settings.stepCount,
                1 //_settings.noiseScale
                , fogData.frameCount));
        cmd.SetRenderTarget(fogData.colorTargets, _depthRT.Identifier());
        cmd.ClearRenderTarget(false, true, Color.black);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref _filteringSettings);
        cmd.SetGlobalTexture(FogDepthTexture, fogData.depthRTs[fogData.curRtIndex]);
    }

    private void DoFilterPass(CommandBuffer cmd, FogCameraData fogData, ref CameraData cameraData)
    {
        var _filterMaterial = fogData.filterMaterial;
        var filterMode = _settings.spatialFilter
            ? _settings.spatialFilterMode
            : VolumetricFogFeature.EFilterMode.Point;
        switch (filterMode)
        {
            case VolumetricFogFeature.EFilterMode.Point:
                _filterMaterial.DisableKeyword("_FilterMode_Gaussian");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral_DepthWeight");
                _filterMaterial.DisableKeyword("_FilterMode_Box4x4");
                break;
            case VolumetricFogFeature.EFilterMode.Gaussian:
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral_DepthWeight");
                _filterMaterial.DisableKeyword("_FilterMode_Box4x4");
                _filterMaterial.EnableKeyword("_FilterMode_Gaussian");
                break;
            case VolumetricFogFeature.EFilterMode.Bilateral:
                _filterMaterial.DisableKeyword("_FilterMode_Gaussian");
                _filterMaterial.DisableKeyword("_FilterMode_Box4x4");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral_DepthWeight");
                _filterMaterial.EnableKeyword("_FilterMode_Bilateral");
                break;
            case VolumetricFogFeature.EFilterMode.BilateralDepthWeighted:
                _filterMaterial.DisableKeyword("_FilterMode_Gaussian");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral");
                _filterMaterial.DisableKeyword("_FilterMode_Box4x4");
                _filterMaterial.EnableKeyword("_FilterMode_Bilateral_DepthWeight");
                break;
            case VolumetricFogFeature.EFilterMode.Box4X4:
                _filterMaterial.DisableKeyword("_FilterMode_Gaussian");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral");
                _filterMaterial.DisableKeyword("_FilterMode_Bilateral_DepthWeight");
                _filterMaterial.EnableKeyword("_FilterMode_Box4x4");
                break;
            default:
                throw new ArgumentOutOfRangeException();
        }

        if (_settings.temporalFilter && fogData.hasHistoryRT)
        {
            Matrix4x4 projMatrix = GL.GetGPUProjectionMatrix(cameraData.GetProjectionMatrix(), false);
            var viewProj = projMatrix * cameraData.GetViewMatrix();
            _filterMaterial.SetMatrix(ClipToLastClip, fogData.lastViewProj * viewProj.inverse);
            fogData.lastViewProj = viewProj;
            var historyIndex = (fogData.curRtIndex + 1) % 2;
            _filterMaterial.SetTexture(HistoryFogTexture, fogData.colorRTs[historyIndex]);
            var transform = cameraData.camera.transform;
            var currentCameraPos = transform.position;
            var currentCameraForward = transform.forward;
            var historyWeight = _settings.historyWeight;
            historyWeight *= CalculateCameraMoveScale(fogData.lastCameraPos, fogData.lastCameraForward,
                currentCameraPos, currentCameraForward);
            _filterMaterial.SetVector(TemporalFilterParam,
                new Vector4(historyWeight, fogData.lastCameraPos.x, fogData.lastCameraPos.y,
                    fogData.lastCameraPos.z));
            _filterMaterial.SetVector(TemporalFilterParam2, currentCameraForward);
            fogData.lastCameraPos = currentCameraPos;
            fogData.lastCameraForward = currentCameraForward;

            if (_settings.depthClampEnable && fogData.hasHistoryRT)
            {
                _filterMaterial.SetTexture(LastDepthTexture, fogData.depthRTs[historyIndex]);
                _filterMaterial.SetVector(DepthClampParam,
                    new Vector4(_settings.depthClampThresholdMin, _settings.depthClampThresholdMax,
                        _settings.depthClampMaxDistance, _settings.depthClampWeight));
                // if (_settings.depthClampSpread)
                // {
                //     _filterMaterial.DisableKeyword("_DepthClamp");
                //     _filterMaterial.EnableKeyword("_DepthClamp_Neighbor");
                // }
                // else
                {
                    _filterMaterial.DisableKeyword("_DepthClamp_Neighbor");
                    _filterMaterial.EnableKeyword("_DepthClamp");
                }
            }
            else
            {
                _filterMaterial.DisableKeyword("_DepthClamp");
                _filterMaterial.DisableKeyword("_DepthClamp_Neighbor");
            }
        }
        else
        {
            _filterMaterial.SetVector(TemporalFilterParam, Vector4.zero);
        }

        cmd.Blit(fogData.colorTargets[0], fogData.colorRTs[fogData.curRtIndex], _filterMaterial);
    }

    private void DoComposePass(CommandBuffer cmd, FogCameraData fogData)
    {
        var _composeMaterial = fogData.composeMaterial;
        if (_settings.scale < 1f && _settings.depthWeightedUpscale)
        {
            _composeMaterial.EnableKeyword("DepthWeightedUpscale");
        }
        else
        {
            _composeMaterial.DisableKeyword("DepthWeightedUpscale");
        }

        var colorRTs = fogData.colorRTs;
        cmd.Blit(colorRTs[fogData.curRtIndex], _renderer.cameraColorTarget, _composeMaterial);
        if (_settings.temporalFilter)
        {
            fogData.curRtIndex = (fogData.curRtIndex + 1) % 2;
            fogData.hasHistoryRT = true;
        }
        else
        {
            fogData.hasHistoryRT = false;
        }
    }

#if UNITY_2020_1_OR_NEWER
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        base.OnCameraCleanup(cmd);
        cmd.ReleaseTemporaryRT(_fogRT.id);
        cmd.ReleaseTemporaryRT(_depthRT.id);
    }
#else
    public override void FrameCleanup(CommandBuffer cmd)
    {
        base.FrameCleanup(cmd);
        cmd.ReleaseTemporaryRT(_fogRT.id);
        cmd.ReleaseTemporaryRT(_depthRT.id);
    }

#endif

    private float CalculateCameraMoveScale(Vector3 lastCameraPos, Vector3 lastCameraForward, Vector3 currentCameraPos,
        Vector3 currentCameraForward)
    {
        if (_settings.cameraGhostAdjust > 0)
        {
            var deltaPos = Vector3.Distance(lastCameraPos, currentCameraPos);
            var deltaRotate = Vector3.Angle(lastCameraForward, currentCameraForward);
            var cameraMoveWeight =
                Mathf.Clamp01(deltaPos * _settings.cameraMoveWeight +
                              deltaRotate * _settings.cameraRotateWeight); //modify or expose the weights if needed  
            // if (cameraMoveWeight > 0.5f)
            // {
            //     Debug.LogError(
            //         $"{cameraMoveWeight}, deltaPos: {deltaPos * _settings.cameraMoveWeight}, deltaRotate: {deltaRotate * _settings.cameraRotateWeight}");
            // }

            return 1 - _settings.cameraGhostAdjust * cameraMoveWeight;
        }

        return 1;
    }

    private void ConfigureColorTextureDesc(ref RenderTextureDescriptor descriptor, RenderTextureFormat textureFormat)
    {
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;
        descriptor.width = (int) (descriptor.width * _settings.scale);
        descriptor.height = (int) (descriptor.height * _settings.scale);
        descriptor.colorFormat = textureFormat;
    }

    private void ConfigureDepthTextureDesc(ref RenderTextureDescriptor descriptor)
    {
        descriptor.colorFormat = RenderTextureFormat.Depth;
        descriptor.depthBufferBits = 32;
        descriptor.msaaSamples = 1;
    }

    private float Halton(int index)
    {
        float res = 0.0f;
        float fraction = 0.5f;
        while (index > 0)
        {
            res += (index & 1) * fraction;
            index >>= 1;
            fraction *= 0.5f;
        }

        return res;
    }

    /*
    private float Halton2(int index, int Base = 2)
    {
        if (Base < 2) Base = 2;
        float res = 0.0f;
        float invBase = 1.0f / Base;
        float fraction = invBase;
        while (index > 0)
        {
            res += (index % Base) * fraction;
            index /= Base;
            fraction *= invBase;
        }

        return res;
    }
*/

    public void Dispose()
    {
        _renderer = null;
        _perCameraDataManager.Dispose();
    }

    private static readonly int FogParam = Shader.PropertyToID("_FogParam");
    private static readonly int FogTextureSize = Shader.PropertyToID("_FogTextureSize");
    private static readonly int ClipToLastClip = Shader.PropertyToID("_ClipToLastClip");
    private static readonly int HistoryFogTexture = Shader.PropertyToID("_HistoryFogTexture");
    private static readonly int TemporalFilterParam = Shader.PropertyToID("_TemporalFilterParam");
    private static readonly int TemporalFilterParam2 = Shader.PropertyToID("_TemporalFilterParam2");
    private static readonly int NoiseMap = Shader.PropertyToID("_NoiseMap");
    private static readonly int NoiseMapTexelSize = Shader.PropertyToID("_NoiseMap_TexelSize");
    private static readonly string[] FogTexNames = {"FogFinalTexture1", "FogFinalTexture2"};
    private static readonly string[] FogDepthTexNames = {"FogDepthTexture1", "FogDepthTexture2"};
    private static readonly int LastDepthTexture = Shader.PropertyToID("_LastDepthTexture");
    private static readonly int DepthClampParam = Shader.PropertyToID("_DepthClampParam");
    private static readonly int MyInvViewProjMatrix = Shader.PropertyToID("_MyInvViewProjMatrix");
    private static readonly int FogDepthTexture = Shader.PropertyToID("_FogDepthTexture");
    private const string LastFogDepthTexName = "LastFogDepthTexture";

    [ExecuteAlways]
    public class CameraEventHelper : MonoBehaviour
    {
        public Action<Camera> OnCameraDisable;

        public void OnDisable()
        {
            OnCameraDisable?.Invoke(GetComponent<Camera>());
        }
    }

    private class PerCameraDataManager<T> where T : IDisposable, new()
    {
        private Dictionary<Camera, T> _dataDic = new Dictionary<Camera, T>();

        public T GetOrAddData(Camera camera)
        {
            if (!_dataDic.TryGetValue(camera, out var data))
            {
                data = new T();
                _dataDic.Add(camera, data);
                var cameraEvent = camera.GetComponent<CameraEventHelper>();
                if (cameraEvent == null)
                    cameraEvent = camera.gameObject.AddComponent<CameraEventHelper>();
                cameraEvent.OnCameraDisable = OnCameraDisable;
                cameraEvent.hideFlags = HideFlags.HideInInspector | HideFlags.HideAndDontSave;
            }

            return data;
        }

        public void Dispose()
        {
            foreach (var data in _dataDic.Values)
            {
                data?.Dispose();
            }

            _dataDic.Clear();
        }

        private void OnCameraDisable(Camera camera)
        {
            if (_dataDic.TryGetValue(camera, out var data))
            {
                data.Dispose();
                _dataDic.Remove(camera);
            }
        }
    }
}