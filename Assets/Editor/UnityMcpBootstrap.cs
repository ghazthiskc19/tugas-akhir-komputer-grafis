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
            EditorApplication.update += StartWhenReady;
        }

        private static void StartWhenReady()
        {
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
                return;

            EditorApplication.update -= StartWhenReady;
            if (!StdioBridgeHost.IsRunning)
                StdioBridgeHost.StartAutoConnect();
        }
    }
}
