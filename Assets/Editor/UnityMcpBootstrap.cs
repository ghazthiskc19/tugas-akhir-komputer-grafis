using MCPForUnity.Editor.Services;
using MCPForUnity.Editor.Services.Transport.Transports;
using UnityEditor;
using UnityEngine;

namespace KomputerGrafis.Editor
{
    [InitializeOnLoad]
    internal static class UnityMcpBootstrap
    {
        static UnityMcpBootstrap()
        {
            if (Application.isBatchMode)
                return;

            // Match Codex's stdio connection for this project without changing global preferences.
            EditorConfigurationCache.Instance.PinStdioForSession();
            EditorApplication.delayCall += StartWhenReady;
        }

        private static void StartWhenReady()
        {
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
            {
                EditorApplication.delayCall += StartWhenReady;
                return;
            }

            StdioBridgeHost.StartAutoConnect();
        }
    }
}
