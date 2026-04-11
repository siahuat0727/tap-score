{{flutter_js}}
{{flutter_build_config}}

const tapScoreDeployId = '__TAP_SCORE_DEPLOY_ID__';

function tapScoreAppendDeployId(assetPath) {
  const separator = assetPath.includes('?') ? '&' : '?';
  return `${assetPath}${separator}v=${encodeURIComponent(tapScoreDeployId)}`;
}

for (const build of _flutter.buildConfig?.builds ?? []) {
  if (typeof build.mainJsPath === 'string') {
    build.mainJsPath = tapScoreAppendDeployId(build.mainJsPath);
  }
  if (typeof build.mainWasmPath === 'string') {
    build.mainWasmPath = tapScoreAppendDeployId(build.mainWasmPath);
  }
  if (typeof build.jsSupportRuntimePath === 'string') {
    build.jsSupportRuntimePath = tapScoreAppendDeployId(
      build.jsSupportRuntimePath,
    );
  }
}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      window.tapScoreBootstrap?.setStage('engine');
      const appRunner = await engineInitializer.initializeEngine();
      window.tapScoreBootstrap?.setStage('launch');
      await appRunner.runApp();
    } catch (error) {
      window.tapScoreBootstrap?.fail(
        'Tap Score could not start in this browser session. Reload to try again.'
      );
      throw error;
    }
  },
});
