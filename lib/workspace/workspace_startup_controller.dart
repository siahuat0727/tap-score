import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, immutable;
import 'package:flutter/widgets.dart' show VoidCallback;

import '../app/score_seed_config.dart';
import '../app/workspace_launch_config.dart';
import '../services/audio_service.dart';
import '../state/rhythm_test_notifier.dart';
import '../state/score_notifier.dart';

typedef WorkspaceRouteSync =
    void Function(WorkspaceMode mode, String? shareablePresetId);

enum WorkspaceStartupPhase {
  preparingWorkspace,
  preparingRenderer,
  preparingRhythmTestAudio,
  retryingRhythmTestAudio,
  ready,
  failed,
}

enum WorkspaceStartupFailureKind { workspace, rhythmTestAudio }

enum WorkspaceStartupStepState { pending, active, complete, error }

@immutable
class WorkspaceStartupState {
  const WorkspaceStartupState({
    required this.mode,
    required this.phase,
    required this.workspaceLabel,
    required this.rendererLabel,
    required this.audioLabel,
    required this.rendererSession,
    required this.workspacePrepared,
    required this.rendererReady,
    required this.audioReady,
    this.failureKind,
    this.errorMessage,
  });

  factory WorkspaceStartupState.initial(WorkspaceLaunchConfig launchConfig) {
    final mode = launchConfig.initialMode;
    return WorkspaceStartupState(
      mode: mode,
      phase: WorkspaceStartupPhase.preparingWorkspace,
      workspaceLabel: workspaceLabelForLaunchConfig(launchConfig),
      rendererLabel: rendererLabelForMode(mode),
      audioLabel: 'Initializing Web Audio',
      rendererSession: 0,
      workspacePrepared: false,
      rendererReady: false,
      audioReady: false,
    );
  }

  final WorkspaceMode mode;
  final WorkspaceStartupPhase phase;
  final WorkspaceStartupFailureKind? failureKind;
  final String? errorMessage;
  final String workspaceLabel;
  final String rendererLabel;
  final String audioLabel;
  final int rendererSession;
  final bool workspacePrepared;
  final bool rendererReady;
  final bool audioReady;

  bool get ready => phase == WorkspaceStartupPhase.ready;

  bool get failed => phase == WorkspaceStartupPhase.failed;

  bool get showsOverlay => !ready;

  bool get requiresAudioStep => mode == WorkspaceMode.rhythmTest;

  String get title => switch (phase) {
    WorkspaceStartupPhase.preparingWorkspace => 'Preparing workspace',
    WorkspaceStartupPhase.preparingRenderer =>
      mode == WorkspaceMode.compose
          ? 'Preparing editor'
          : 'Preparing rhythm test',
    WorkspaceStartupPhase.preparingRhythmTestAudio => 'Preparing rhythm test',
    WorkspaceStartupPhase.retryingRhythmTestAudio =>
      'Retrying rhythm test audio',
    WorkspaceStartupPhase.ready => 'Tap Score is ready',
    WorkspaceStartupPhase.failed =>
      failureKind == WorkspaceStartupFailureKind.rhythmTestAudio
          ? 'Rhythm test unavailable'
          : 'Workspace unavailable',
  };

  String get detail => switch (phase) {
    WorkspaceStartupPhase.preparingWorkspace => workspaceLabel,
    WorkspaceStartupPhase.preparingRenderer =>
      mode == WorkspaceMode.compose
          ? 'Loading the score renderer before opening the editor.'
          : 'Loading the rhythm test surface before entering the page.',
    WorkspaceStartupPhase.preparingRhythmTestAudio => audioLabel,
    WorkspaceStartupPhase.retryingRhythmTestAudio => audioLabel,
    WorkspaceStartupPhase.ready => 'Workspace setup finished.',
    WorkspaceStartupPhase.failed => errorMessage ?? 'Workspace setup failed.',
  };

  WorkspaceStartupStepState get workspaceStepState {
    if (failed && failureKind == WorkspaceStartupFailureKind.workspace) {
      return WorkspaceStartupStepState.error;
    }
    if (!workspacePrepared) {
      return WorkspaceStartupStepState.active;
    }
    return WorkspaceStartupStepState.complete;
  }

  WorkspaceStartupStepState get rendererStepState {
    if (!workspacePrepared) {
      return WorkspaceStartupStepState.pending;
    }
    if (rendererReady) {
      return WorkspaceStartupStepState.complete;
    }
    if (failed && failureKind == WorkspaceStartupFailureKind.workspace) {
      return WorkspaceStartupStepState.pending;
    }
    return WorkspaceStartupStepState.active;
  }

  WorkspaceStartupStepState get audioStepState {
    if (!requiresAudioStep || !workspacePrepared) {
      return WorkspaceStartupStepState.pending;
    }
    if (failed && failureKind == WorkspaceStartupFailureKind.rhythmTestAudio) {
      return WorkspaceStartupStepState.error;
    }
    if (audioReady) {
      return WorkspaceStartupStepState.complete;
    }
    return WorkspaceStartupStepState.active;
  }

  WorkspaceStartupState copyWith({
    WorkspaceMode? mode,
    WorkspaceStartupPhase? phase,
    WorkspaceStartupFailureKind? failureKind,
    bool clearFailureKind = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? workspaceLabel,
    String? rendererLabel,
    String? audioLabel,
    int? rendererSession,
    bool? workspacePrepared,
    bool? rendererReady,
    bool? audioReady,
  }) {
    return WorkspaceStartupState(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      failureKind: clearFailureKind ? null : failureKind ?? this.failureKind,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      workspaceLabel: workspaceLabel ?? this.workspaceLabel,
      rendererLabel: rendererLabel ?? this.rendererLabel,
      audioLabel: audioLabel ?? this.audioLabel,
      rendererSession: rendererSession ?? this.rendererSession,
      workspacePrepared: workspacePrepared ?? this.workspacePrepared,
      rendererReady: rendererReady ?? this.rendererReady,
      audioReady: audioReady ?? this.audioReady,
    );
  }
}

String workspaceLabelForLaunchConfig(WorkspaceLaunchConfig launchConfig) {
  return switch (launchConfig.seedConfig.kind) {
    ScoreSeedKind.restore => 'Restoring last workspace',
    ScoreSeedKind.blank => 'Creating empty workspace',
    ScoreSeedKind.preset => 'Loading preset',
    ScoreSeedKind.saved => 'Loading saved score',
    ScoreSeedKind.imported => 'Importing score',
  };
}

String rendererLabelForMode(WorkspaceMode mode) {
  return switch (mode) {
    WorkspaceMode.compose => 'Loading editor surface',
    WorkspaceMode.rhythmTest => 'Loading rhythm test surface',
  };
}

String audioLabelForPhase(
  RhythmTestPreparationPhase phase, {
  required bool retrying,
}) {
  return switch (phase) {
    RhythmTestPreparationPhase.initializingAudio =>
      retrying ? 'Retrying Web Audio initialization' : 'Initializing Web Audio',
    RhythmTestPreparationPhase.preloadingNotes =>
      retrying
          ? 'Retrying rhythm test note preload'
          : 'Preloading rhythm test notes',
  };
}

class WorkspaceStartupController extends ChangeNotifier {
  WorkspaceStartupController({
    required ScoreNotifier scoreNotifier,
    required WorkspaceLaunchConfig launchConfig,
    required VoidCallback requestFocus,
    required WorkspaceRouteSync? onRouteSync,
    AudioService? rhythmTestAudioService,
    Duration rhythmTestAudioTimeout = const Duration(seconds: 12),
  }) : _scoreNotifier = scoreNotifier,
       _launchConfig = launchConfig,
       _requestFocus = requestFocus,
       _onRouteSync = onRouteSync,
       _rhythmTestAudioService = rhythmTestAudioService,
       _rhythmTestAudioTimeout = rhythmTestAudioTimeout,
       _state = WorkspaceStartupState.initial(launchConfig);

  final ScoreNotifier _scoreNotifier;
  final WorkspaceLaunchConfig _launchConfig;
  final VoidCallback _requestFocus;
  final WorkspaceRouteSync? _onRouteSync;
  final AudioService? _rhythmTestAudioService;
  final Duration _rhythmTestAudioTimeout;

  WorkspaceStartupState _state;
  RhythmTestNotifier? _rhythmTestNotifier;
  int _startupPass = 0;
  bool _disposed = false;

  WorkspaceStartupState get state => _state;

  WorkspaceMode get mode => _state.mode;

  RhythmTestNotifier? get rhythmTestNotifier => _rhythmTestNotifier;

  Future<void> start() async {
    final pass = ++_startupPass;

    _disposeRhythmTestNotifier();
    _setState(
      WorkspaceStartupState.initial(_launchConfig).copyWith(
        rendererSession: _state.rendererSession + 1,
        audioReady: _launchConfig.initialMode == WorkspaceMode.compose,
      ),
    );

    await _scoreNotifier.loadInitialWorkspace(
      initialScoreConfig: _launchConfig.seedConfig,
    );
    if (!_isActivePass(pass)) {
      return;
    }

    if (!_scoreNotifier.initialWorkspaceLoadSucceeded) {
      _failStartup(
        kind: WorkspaceStartupFailureKind.workspace,
        message:
            _scoreNotifier.libraryMessage ?? 'Failed to load the workspace.',
      );
      return;
    }

    _configureBodyAfterWorkspaceLoad();
    if (!_isActivePass(pass)) {
      return;
    }

    _maybeCompleteStartup();
    if (_state.ready) {
      return;
    }

    if (_requiresRhythmTestAudioGate()) {
      unawaited(_prepareRhythmTestAudio(pass: pass, attempt: 1));
      return;
    }

    _setState(_state.copyWith(phase: WorkspaceStartupPhase.preparingRenderer));
  }

  Future<void> switchMode(WorkspaceMode nextMode) async {
    if (!_state.ready || nextMode == _state.mode) {
      return;
    }

    if (nextMode == WorkspaceMode.compose) {
      _disposeRhythmTestNotifier();
      _startupPass += 1;
      _setState(
        _state.copyWith(
          mode: WorkspaceMode.compose,
          phase: WorkspaceStartupPhase.preparingRenderer,
          clearFailureKind: true,
          clearErrorMessage: true,
          workspaceLabel: 'Current workspace ready',
          rendererLabel: rendererLabelForMode(WorkspaceMode.compose),
          rendererSession: _state.rendererSession + 1,
          workspacePrepared: true,
          rendererReady: false,
          audioReady: true,
        ),
      );
      _maybeCompleteStartup();
      _syncRoute();
      return;
    }

    _configureRhythmTestBody(nextMode: WorkspaceMode.rhythmTest);
    final requiresAudio =
        _rhythmTestNotifier != null && _scoreNotifier.score.notes.isNotEmpty;
    final requiresRenderer = requiresAudio;
    final pass = ++_startupPass;
    _setState(
      _state.copyWith(
        mode: WorkspaceMode.rhythmTest,
        phase: requiresAudio
            ? WorkspaceStartupPhase.preparingRhythmTestAudio
            : WorkspaceStartupPhase.preparingRenderer,
        clearFailureKind: true,
        clearErrorMessage: true,
        workspaceLabel: 'Current workspace ready',
        rendererLabel: rendererLabelForMode(WorkspaceMode.rhythmTest),
        audioLabel: 'Initializing Web Audio',
        rendererSession: _state.rendererSession + 1,
        workspacePrepared: true,
        rendererReady: !requiresRenderer,
        audioReady: !requiresAudio,
      ),
    );
    _maybeCompleteStartup();
    if (!_state.ready && requiresAudio) {
      unawaited(_prepareRhythmTestAudio(pass: pass, attempt: 1));
    }
    _syncRoute();
  }

  void markRendererReady(int rendererSession) {
    if (rendererSession != _state.rendererSession || _state.rendererReady) {
      return;
    }
    _setState(_state.copyWith(rendererReady: true));
    _maybeCompleteStartup();
  }

  Future<void> retry() async {
    if (_state.failureKind == WorkspaceStartupFailureKind.rhythmTestAudio &&
        _requiresRhythmTestAudioGate()) {
      unawaited(_prepareRhythmTestAudio(pass: ++_startupPass, attempt: 1));
      return;
    }

    await start();
  }

  void _configureBodyAfterWorkspaceLoad() {
    _configureRhythmTestBody(nextMode: _state.mode);
    final requiresRenderer = _requiresRendererGate();
    final requiresAudio = _requiresRhythmTestAudioGate();
    _setState(
      _state.copyWith(
        workspacePrepared: true,
        rendererReady: !requiresRenderer,
        audioReady: !requiresAudio,
        phase: requiresAudio
            ? WorkspaceStartupPhase.preparingRhythmTestAudio
            : requiresRenderer
            ? WorkspaceStartupPhase.preparingRenderer
            : WorkspaceStartupPhase.ready,
      ),
    );
  }

  void _configureRhythmTestBody({required WorkspaceMode nextMode}) {
    if (nextMode != WorkspaceMode.rhythmTest) {
      _disposeRhythmTestNotifier();
      return;
    }

    _scoreNotifier.stop();
    if (_scoreNotifier.score.notes.isEmpty) {
      _disposeRhythmTestNotifier();
      return;
    }

    final previousNotifier = _rhythmTestNotifier;
    _rhythmTestNotifier = RhythmTestNotifier(
      score: _scoreNotifier.score,
      referenceBpm: _scoreNotifier.referenceBpm,
      audioService: _rhythmTestAudioService,
    );
    previousNotifier?.dispose();
  }

  bool _requiresRendererGate() {
    if (_state.mode == WorkspaceMode.compose) {
      return true;
    }
    return _rhythmTestNotifier != null && _scoreNotifier.score.notes.isNotEmpty;
  }

  bool _requiresRhythmTestAudioGate() {
    if (_state.mode != WorkspaceMode.rhythmTest) {
      return false;
    }
    return _rhythmTestNotifier != null && _scoreNotifier.score.notes.isNotEmpty;
  }

  Future<void> _prepareRhythmTestAudio({
    required int pass,
    required int attempt,
  }) async {
    if (!_isActivePass(pass)) {
      return;
    }

    final notifier = _rhythmTestNotifier;
    if (notifier == null) {
      _setState(_state.copyWith(audioReady: true));
      _maybeCompleteStartup();
      return;
    }

    final retrying = attempt > 1;
    _setState(
      _state.copyWith(
        phase: retrying
            ? WorkspaceStartupPhase.retryingRhythmTestAudio
            : WorkspaceStartupPhase.preparingRhythmTestAudio,
        clearFailureKind: true,
        clearErrorMessage: true,
        audioLabel: audioLabelForPhase(
          RhythmTestPreparationPhase.initializingAudio,
          retrying: retrying,
        ),
      ),
    );

    await notifier.init(
      audioTimeout: _rhythmTestAudioTimeout,
      onPreparationPhaseChanged: (phase) {
        if (!_isActivePass(pass)) {
          return;
        }
        _setState(
          _state.copyWith(
            audioLabel: audioLabelForPhase(phase, retrying: retrying),
          ),
        );
      },
    );
    if (!_isActivePass(pass)) {
      return;
    }

    if (notifier.isInitialized) {
      _setState(_state.copyWith(audioReady: true));
      _maybeCompleteStartup();
      return;
    }

    if (attempt == 1) {
      final retryPass = ++_startupPass;
      _setState(
        _state.copyWith(
          phase: WorkspaceStartupPhase.retryingRhythmTestAudio,
          audioLabel: 'The first audio attempt timed out. Retrying once.',
        ),
      );
      await _prepareRhythmTestAudio(pass: retryPass, attempt: 2);
      return;
    }

    _failStartup(
      kind: WorkspaceStartupFailureKind.rhythmTestAudio,
      message:
          notifier.errorMessage ?? 'Rhythm test audio failed to initialize.',
    );
  }

  void _maybeCompleteStartup() {
    final rendererReady = !_requiresRendererGate() || _state.rendererReady;
    final audioReady = !_requiresRhythmTestAudioGate() || _state.audioReady;
    if (!_state.workspacePrepared || !rendererReady || !audioReady) {
      return;
    }

    _syncRoute();
    _requestFocus();
    _setState(
      _state.copyWith(
        phase: WorkspaceStartupPhase.ready,
        clearFailureKind: true,
        clearErrorMessage: true,
      ),
    );
  }

  void _failStartup({
    required WorkspaceStartupFailureKind kind,
    required String message,
  }) {
    _setState(
      _state.copyWith(
        phase: WorkspaceStartupPhase.failed,
        failureKind: kind,
        errorMessage: message,
      ),
    );
  }

  String? _shareablePresetId() {
    if (_scoreNotifier.hasUnsavedChanges) {
      return null;
    }
    return _scoreNotifier.activePresetId;
  }

  void _syncRoute() {
    _onRouteSync?.call(_state.mode, _shareablePresetId());
  }

  void _disposeRhythmTestNotifier() {
    final previousNotifier = _rhythmTestNotifier;
    _rhythmTestNotifier = null;
    previousNotifier?.dispose();
  }

  bool _isActivePass(int pass) {
    return !_disposed && pass == _startupPass;
  }

  void _setState(WorkspaceStartupState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _startupPass += 1;
    _disposeRhythmTestNotifier();
    super.dispose();
  }
}
