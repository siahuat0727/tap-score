{{flutter_js}}
{{flutter_build_config}}

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
