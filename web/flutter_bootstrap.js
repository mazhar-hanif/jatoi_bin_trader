{{flutter_js}}
{{flutter_build_config}}

function reportBootstrapFailure(error) {
  window.dispatchEvent(
    new CustomEvent('jatoi-flutter-error', { detail: String(error) }),
  );
}

try {
  const loading = _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
        window.dispatchEvent(new Event('jatoi-flutter-ready'));
      } catch (error) {
        reportBootstrapFailure(error);
      }
    },
  });
  if (loading && typeof loading.catch === 'function') {
    loading.catch(reportBootstrapFailure);
  }
} catch (error) {
  reportBootstrapFailure(error);
}
