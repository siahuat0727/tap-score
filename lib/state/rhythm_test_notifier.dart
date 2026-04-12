import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/score.dart';
import '../rhythm_test/rhythm_matcher.dart';
import '../rhythm_test/rhythm_test_models.dart';
import '../rhythm_test/rhythm_timeline_builder.dart';
import '../services/audio_service.dart';
import '../services/playback_schedule.dart';

enum RhythmTestPhase { idle, countIn, running, finished }

class RhythmTestNotifier extends ChangeNotifier {
  static const Duration resultRevealLockDuration = Duration(seconds: 1);
  static const Duration _visualPlayheadUpdateInterval = Duration(
    milliseconds: 33,
  );

  RhythmTestNotifier({
    required Score score,
    AudioService? audioService,
    RhythmTimelineBuilder? timelineBuilder,
    RhythmMatcher? matcher,
    RhythmTestDisplayConfig displayConfig = const RhythmTestDisplayConfig(),
    Stopwatch Function()? createStopwatch,
    Future<void> Function()? waitBeforeScoring,
  }) : _score = score.copy(),
       _audioService = audioService ?? AudioService(),
       _timelineBuilder = timelineBuilder ?? const RhythmTimelineBuilder(),
       _matcher = matcher ?? const RhythmMatcher(),
       _displayConfig = displayConfig,
       _createStopwatch = createStopwatch ?? Stopwatch.new,
       _waitBeforeScoring = waitBeforeScoring ?? _waitBeforeScoringDefault {
    _largeErrorThresholdBeats = displayConfig.largeErrorThresholdBeats;
    _timeline = _timelineBuilder.build(_score);
  }

  final Score _score;
  final AudioService _audioService;
  final RhythmTimelineBuilder _timelineBuilder;
  final RhythmMatcher _matcher;
  final RhythmTestDisplayConfig _displayConfig;
  final Stopwatch Function() _createStopwatch;
  final Future<void> Function() _waitBeforeScoring;
  late double _largeErrorThresholdBeats;

  late RhythmTimeline _timeline;

  RhythmTestPhase _phase = RhythmTestPhase.idle;
  bool _isInitialized = false;
  String? _errorMessage;
  RhythmTestResult? _result;
  bool _isScoringResult = false;
  String? _scoringErrorMessage;
  final List<TapInputEvent> _tapEvents = [];
  int _nextTapId = 0;
  int _sessionId = 0;
  Stopwatch? _sessionStopwatch;
  int? _performanceStartMicros;
  int? _countInPulseIndex;
  int? _runningPulseIndex;
  int _playbackNoteIndex = -1;
  double _elapsedRunSeconds = 0;
  double _playheadTimeSeconds = 0;
  final double _postRollPulseCount = 1.0;
  bool _restartLocked = false;
  Timer? _restartUnlockTimer;
  final Map<int, AudioNoteHandle> _activePlaybackHandles = {};
  bool _resultCardVisible = true;
  bool _isDisposed = false;
  int _lastVisualNotifyMicros = -1;

  Score get score => _score;

  RhythmTimeline get timeline => _timeline;

  RhythmTestPhase get phase => _phase;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  RhythmTestResult? get result => _result;

  bool get isScoringResult => _isScoringResult;

  String? get scoringErrorMessage => _scoringErrorMessage;

  RhythmTestDisplayConfig get displayConfig => _displayConfig;

  double get largeErrorThresholdBeats => _largeErrorThresholdBeats;

  List<TapInputEvent> get tapEvents => List.unmodifiable(_tapEvents);

  RhythmOverlayRenderData get overlayRenderData {
    final largeErrorThresholdSeconds =
        _largeErrorThresholdBeats * _timeline.pulseDurationSeconds;
    final result = _result;
    final resultTapEvents = [
      if (result != null) ...[
        for (final pair in result.matchedPairs)
          result.displayTapEvent(pair.tap),
        for (final tap in result.unmatchedTapEvents)
          result.displayTapEvent(tap),
      ],
    ]..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));

    return RhythmOverlayRenderData(
      phase: _overlayRenderPhase,
      shouldAutoFollowPlayback:
          _phase == RhythmTestPhase.countIn ||
          _phase == RhythmTestPhase.running,
      elapsedRunSeconds: _elapsedRunSeconds,
      playheadTimeSeconds: _playheadTimeSeconds,
      countInDurationSeconds: _timeline.countInDurationSeconds,
      totalDurationSeconds: _timeline.totalDurationSeconds,
      pulseDurationSeconds: _timeline.pulseDurationSeconds,
      pulsesPerMeasure: _timeline.pulsesPerMeasure,
      measureBoundaryTimesSeconds: _timeline.measureBoundaryTimesSeconds,
      expectedEvents: _timeline.expectedEvents,
      liveTapEvents: List.unmodifiable(_tapEvents),
      resultTapEvents: List.unmodifiable(resultTapEvents),
      matchedPairs: result?.matchedPairs ?? const <MatchedRhythmPair>[],
      appliedShiftSeconds: result?.appliedShiftSeconds ?? 0,
      errorLabelThresholdBeats: _displayConfig.errorLabelThresholdBeats,
      largeErrorThresholdBeats: _largeErrorThresholdBeats,
      largeErrorNoteIndices:
          result?.largeErrorExpectedNoteIndicesForThreshold(
            largeErrorThresholdSeconds,
          ) ??
          const <int>[],
      missedExpectedNoteIndices:
          result?.missedExpectedNoteIndices ?? const <int>[],
    );
  }

  int? get countInPulseIndex => _countInPulseIndex;

  int? get runningPulseIndex => _runningPulseIndex;

  int get playbackNoteIndex => _playbackNoteIndex;

  double get elapsedRunSeconds => _elapsedRunSeconds;

  double get playheadTimeSeconds => _playheadTimeSeconds;

  bool get showsExpectedAnswers =>
      _overlayRenderPhase == RhythmOverlayRenderPhase.result;

  bool get restartLocked => _restartLocked;

  bool get isBusy =>
      _phase == RhythmTestPhase.countIn || _phase == RhythmTestPhase.running;

  bool get canStart =>
      !isBusy &&
      !_restartLocked &&
      _errorMessage == null &&
      _isInitialized &&
      _timeline.expectedEvents.isNotEmpty;

  bool get showCenteredResult =>
      _resultCardVisible &&
      (_isScoringResult || _scoringErrorMessage != null || _result != null);

  RhythmOverlayRenderPhase get _overlayRenderPhase {
    if (_phase == RhythmTestPhase.countIn ||
        _phase == RhythmTestPhase.running) {
      return RhythmOverlayRenderPhase.live;
    }
    if (_phase == RhythmTestPhase.finished && _result != null) {
      return RhythmOverlayRenderPhase.result;
    }
    if (_phase == RhythmTestPhase.finished) {
      return RhythmOverlayRenderPhase.pendingResult;
    }
    return RhythmOverlayRenderPhase.idle;
  }

  bool get canStop =>
      _phase == RhythmTestPhase.countIn || _phase == RhythmTestPhase.running;

  int get resultErrorCount => _result?.errorCount ?? 0;

  String get resultErrorCountLabel => '$resultErrorCount';

  int get resultLargeErrorCount {
    final result = _result;
    if (result == null) {
      return 0;
    }
    return result.largeErrorCountForThreshold(
      _largeErrorThresholdBeats * _timeline.pulseDurationSeconds,
    );
  }

  String get resultLargeErrorCountLabel => '$resultLargeErrorCount';

  double? get resultAverageErrorBeats {
    final averageErrorSeconds = _result?.shiftedAverageAbsoluteErrorSeconds;
    if (averageErrorSeconds == null) {
      return null;
    }
    return averageErrorSeconds / _timeline.pulseDurationSeconds;
  }

  double? get resultMaxErrorBeats {
    final maxErrorSeconds = _result?.maxAbsoluteErrorSeconds;
    if (maxErrorSeconds == null) {
      return null;
    }
    return maxErrorSeconds / _timeline.pulseDurationSeconds;
  }

  String get resultShiftLabel {
    final result = _result;
    if (result == null) {
      return '';
    }
    final shiftBeats =
        result.appliedShiftSeconds / _timeline.pulseDurationSeconds;
    return '${shiftBeats >= 0 ? '+' : ''}${shiftBeats.toStringAsFixed(2)} beat';
  }

  String get resultStatusLabel {
    if (resultErrorCount > 0) {
      return 'Failed';
    }
    if (resultLargeErrorCount > 0) {
      return 'Clean, but loose';
    }
    return 'Perfect';
  }

  String get resultSummaryLabel =>
      'BPM ${_score.bpm.round()} · Shift $resultShiftLabel';

  String get largeOffsetThresholdLabel =>
      '${_largeErrorThresholdBeats.toStringAsFixed(2)} beat';

  String get primaryActionLabel => isBusy ? 'Tap' : 'Start';

  String get primaryActionHint => 'Space';

  bool get primaryActionEnabled => isBusy || canStart;

  Future<void> init() async {
    if (_isInitialized || _errorMessage != null) {
      _emitChange();
      return;
    }

    final initialized = await _audioService.init();
    if (!initialized) {
      _errorMessage =
          _audioService.initializationError ??
          'Rhythm test metronome is unavailable on this platform or audio failed to initialize.';
      _emitChange();
      return;
    }

    try {
      await _audioService.preloadRhythmTestNotes(
        _timeline.playbackNotes.map((note) => note.midi),
      );
    } catch (error) {
      _errorMessage = 'Rhythm test audio preparation failed: $error';
      _emitChange();
      return;
    }

    _isInitialized = true;
    _emitChange();
  }

  Future<void> start() async {
    if (isBusy) {
      return;
    }

    if (_timeline.expectedEvents.isEmpty) {
      _errorMessage = 'Rhythm test needs at least one non-rest note onset.';
      _emitChange();
      return;
    }

    if (!_isInitialized) {
      await init();
      if (!_isInitialized) {
        return;
      }
    }

    _sessionId += 1;
    _audioService.stopPlayback();
    _resetSessionState(phase: RhythmTestPhase.countIn);
    _countInPulseIndex = 0;
    _runningPulseIndex = null;
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = -_timeline.countInDurationSeconds;
    _lastVisualNotifyMicros = 0;
    _emitChange();

    unawaited(_runSession(_sessionId));
  }

  Future<void> performPrimaryAction() async {
    if (_phase == RhythmTestPhase.countIn ||
        _phase == RhythmTestPhase.running) {
      recordTap();
      return;
    }
    if (canStart) {
      await start();
    }
  }

  void recordTap() {
    if (_phase != RhythmTestPhase.countIn &&
        _phase != RhythmTestPhase.running) {
      return;
    }

    final stopwatch = _sessionStopwatch;
    final performanceStartMicros = _performanceStartMicros;
    if (stopwatch == null || performanceStartMicros == null) {
      return;
    }

    final elapsedMicros =
        stopwatch.elapsedMicroseconds - performanceStartMicros;
    _tapEvents.add(
      TapInputEvent(
        id: _nextTapId++,
        timeSeconds: elapsedMicros / Duration.microsecondsPerSecond,
      ),
    );
    _lastVisualNotifyMicros = stopwatch.elapsedMicroseconds;
    _emitChange();
  }

  void stop() {
    if (_phase == RhythmTestPhase.idle &&
        _tapEvents.isEmpty &&
        _result == null &&
        !_isScoringResult &&
        _scoringErrorMessage == null) {
      return;
    }

    _sessionId += 1;
    _audioService.stopPlayback();
    _resetSessionState(phase: RhythmTestPhase.idle);
    _emitChange();
  }

  void setTempo(double bpm) {
    if (isBusy) {
      return;
    }

    _sessionId += 1;
    _audioService.stopPlayback();
    _score.bpm = bpm.clamp(40, 240);
    _timeline = _timelineBuilder.build(_score);
    _resetSessionState(phase: RhythmTestPhase.idle);
    _emitChange();
  }

  void setLargeErrorThreshold(double beats) {
    if (isBusy) {
      return;
    }

    _largeErrorThresholdBeats = beats.clamp(0.05, 0.5);
    _emitChange();
  }

  void dismissResultCard() {
    if (!_resultCardVisible) {
      return;
    }
    _resultCardVisible = false;
    _emitChange();
  }

  Future<void> _runSession(int sessionId) async {
    final stopwatch = _createStopwatch()..start();
    _sessionStopwatch = stopwatch;

    final pulseMicros =
        (_timeline.pulseDurationSeconds * Duration.microsecondsPerSecond)
            .round();
    final countInPulseCount = _timeline.countInPulseCount;
    final performanceStartMicros = countInPulseCount * pulseMicros;
    _performanceStartMicros = performanceStartMicros;

    for (var index = 0; index < countInPulseCount; index++) {
      if (!await _waitUntil(
        stopwatch: stopwatch,
        sessionId: sessionId,
        targetMicros: index * pulseMicros,
      )) {
        return;
      }

      _countInPulseIndex = index;
      _audioService.playRhythmTestMetronomeClick(accented: index == 0);
      _lastVisualNotifyMicros = stopwatch.elapsedMicroseconds;
      _emitChange();
    }

    if (!await _waitUntil(
      stopwatch: stopwatch,
      sessionId: sessionId,
      targetMicros: performanceStartMicros,
    )) {
      return;
    }

    _phase = RhythmTestPhase.running;
    _countInPulseIndex = null;
    _runningPulseIndex = 0;
    _playbackNoteIndex = _playbackNoteIndexForElapsed(0);
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = 0;
    _lastVisualNotifyMicros = performanceStartMicros;
    _emitChange();

    final scheduledEvents = _buildScheduledRunEvents(
      performanceStartMicros: performanceStartMicros,
    );
    for (final event in scheduledEvents) {
      if (!await _waitUntil(
        stopwatch: stopwatch,
        sessionId: sessionId,
        targetMicros: event.targetMicros,
      )) {
        return;
      }

      _syncPlaybackProgress(stopwatch);
      switch (event) {
        case _NoteOffPlaybackEvent():
          final handle = _activePlaybackHandles.remove(event.note.noteIndex);
          if (handle != null) {
            await _audioService.stopNoteHandle(handle);
          }
        case _NoteOnPlaybackEvent():
          final handle = await _audioService.startNote(
            event.note.midi,
            velocity: event.note.velocity,
          );
          if (handle != null) {
            _activePlaybackHandles[event.note.noteIndex] = handle;
          }
      }
    }

    final finishMicros =
        performanceStartMicros +
        (_timeline.totalDurationSeconds * Duration.microsecondsPerSecond)
            .round();
    if (!await _waitUntil(
      stopwatch: stopwatch,
      sessionId: sessionId,
      targetMicros: finishMicros,
    )) {
      return;
    }

    _elapsedRunSeconds = _timeline.totalDurationSeconds;
    _playheadTimeSeconds = _timeline.totalDurationSeconds;
    _playbackNoteIndex = -1;
    _lastVisualNotifyMicros = finishMicros;
    _emitChange();

    final graceMicros = (pulseMicros * _postRollPulseCount).round();
    if (!await _waitUntil(
      stopwatch: stopwatch,
      sessionId: sessionId,
      targetMicros: finishMicros + graceMicros,
    )) {
      return;
    }

    _sessionStopwatch?.stop();
    _completeRun(sessionId);
  }

  static Future<void> _waitBeforeScoringDefault() {
    return Future<void>.delayed(Duration.zero);
  }

  Future<bool> _waitUntil({
    required Stopwatch stopwatch,
    required int sessionId,
    required int targetMicros,
  }) async {
    while (sessionId == _sessionId) {
      _syncPlaybackProgress(stopwatch);
      final remainingMicros = targetMicros - stopwatch.elapsedMicroseconds;
      if (remainingMicros <= 0) {
        return true;
      }

      final sleepMicros = remainingMicros > 16000 ? 16000 : remainingMicros;
      await Future<void>.delayed(Duration(microseconds: sleepMicros));
    }

    return false;
  }

  double _currentRunSeconds(Stopwatch stopwatch) {
    final performanceStartMicros = _performanceStartMicros;
    if (performanceStartMicros == null) {
      return 0;
    }
    return (stopwatch.elapsedMicroseconds - performanceStartMicros) /
        Duration.microsecondsPerSecond;
  }

  void _syncPlaybackProgress(Stopwatch stopwatch) {
    if (_phase != RhythmTestPhase.countIn &&
        _phase != RhythmTestPhase.running) {
      return;
    }

    final nextPlayhead = _currentRunSeconds(stopwatch)
        .clamp(
          -_timeline.countInDurationSeconds,
          _timeline.totalDurationSeconds,
        )
        .toDouble();
    final nextElapsed = nextPlayhead
        .clamp(0, _timeline.totalDurationSeconds)
        .toDouble();
    final playheadChanged =
        (nextPlayhead - _playheadTimeSeconds).abs() >= 0.001 ||
        (nextElapsed - _elapsedRunSeconds).abs() >= 0.001;
    if (!playheadChanged) {
      return;
    }

    final previousPulseIndex = _runningPulseIndex;
    final previousPlaybackNoteIndex = _playbackNoteIndex;
    _playheadTimeSeconds = nextPlayhead;
    _elapsedRunSeconds = nextElapsed;
    var runningPulseChanged = false;
    var playbackNoteChanged = false;
    if (_phase == RhythmTestPhase.running) {
      final maxPulseIndex =
          ((_timeline.totalDurationSeconds / _timeline.pulseDurationSeconds)
                      .ceil() -
                  1)
              .clamp(0, 1 << 20);
      final nextPulseIndex = (nextElapsed / _timeline.pulseDurationSeconds)
          .floor()
          .clamp(0, maxPulseIndex)
          .toInt();
      _runningPulseIndex = nextPulseIndex;
      _playbackNoteIndex = _playbackNoteIndexForElapsed(nextElapsed);
      runningPulseChanged = nextPulseIndex != previousPulseIndex;
      playbackNoteChanged = _playbackNoteIndex != previousPlaybackNoteIndex;
    }

    if (runningPulseChanged || playbackNoteChanged) {
      _lastVisualNotifyMicros = stopwatch.elapsedMicroseconds;
      _emitChange();
      return;
    }

    if (_lastVisualNotifyMicros >= 0 &&
        stopwatch.elapsedMicroseconds - _lastVisualNotifyMicros <
            _visualPlayheadUpdateInterval.inMicroseconds) {
      return;
    }

    _lastVisualNotifyMicros = stopwatch.elapsedMicroseconds;
    _emitChange();
  }

  void _completeRun(int sessionId) {
    _phase = RhythmTestPhase.finished;
    _runningPulseIndex = null;
    _countInPulseIndex = null;
    _playbackNoteIndex = -1;
    _result = null;
    _isScoringResult = true;
    _scoringErrorMessage = null;
    _restartLocked = true;
    _resultCardVisible = true;
    _restartUnlockTimer?.cancel();
    _emitChange();
    unawaited(_scoreResult(sessionId));
  }

  Future<void> _scoreResult(int sessionId) async {
    await _waitBeforeScoring();
    if (sessionId != _sessionId ||
        _phase != RhythmTestPhase.finished ||
        !_isScoringResult) {
      return;
    }

    try {
      final result = _matcher.match(
        expectedEvents: _timeline.expectedEvents,
        tapEvents: _tapEvents,
        matchingWindowSeconds: _timeline.matchingWindowSeconds,
      );
      if (sessionId != _sessionId ||
          _phase != RhythmTestPhase.finished ||
          !_isScoringResult) {
        return;
      }

      _result = result;
      _isScoringResult = false;
      _resultCardVisible = true;
      _restartUnlockTimer = Timer(resultRevealLockDuration, () {
        if (sessionId != _sessionId || _phase != RhythmTestPhase.finished) {
          return;
        }
        _restartLocked = false;
        _emitChange();
      });
      _emitChange();
    } catch (error) {
      if (sessionId != _sessionId ||
          _phase != RhythmTestPhase.finished ||
          !_isScoringResult) {
        return;
      }

      _isScoringResult = false;
      _restartLocked = false;
      _scoringErrorMessage = 'Rhythm test result calculation failed: $error';
      _resultCardVisible = true;
      _emitChange();
    }
  }

  void _emitChange() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  void _resetSessionState({required RhythmTestPhase phase}) {
    _restartUnlockTimer?.cancel();
    _sessionStopwatch?.stop();
    _phase = phase;
    _countInPulseIndex = null;
    _runningPulseIndex = null;
    _playbackNoteIndex = -1;
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = 0;
    _result = null;
    _isScoringResult = false;
    _scoringErrorMessage = null;
    _resultCardVisible = true;
    _tapEvents.clear();
    _nextTapId = 0;
    _performanceStartMicros = null;
    _sessionStopwatch = null;
    _restartLocked = false;
    _activePlaybackHandles.clear();
    _lastVisualNotifyMicros = -1;
  }

  int _playbackNoteIndexForElapsed(double elapsedSeconds) {
    if (elapsedSeconds < 0 ||
        elapsedSeconds >= _timeline.totalDurationSeconds) {
      return -1;
    }

    for (final step in _timeline.playbackSteps) {
      final endSeconds = step.startSeconds + step.durationSeconds;
      if (elapsedSeconds < step.startSeconds) {
        break;
      }
      if (elapsedSeconds < endSeconds) {
        return step.noteIndex;
      }
    }

    return -1;
  }

  List<_ScheduledRunEvent> _buildScheduledRunEvents({
    required int performanceStartMicros,
  }) {
    final scheduledEvents = <_ScheduledRunEvent>[];

    for (final playbackEvent in buildScheduledPlaybackEvents(
      _timeline.playbackNotes,
    )) {
      final targetMicros = performanceStartMicros + playbackEvent.targetMicros;
      switch (playbackEvent.type) {
        case ScheduledPlaybackEventType.noteOff:
          scheduledEvents.add(
            _NoteOffPlaybackEvent(
              targetMicros: targetMicros,
              note: playbackEvent.note,
            ),
          );
        case ScheduledPlaybackEventType.noteOn:
          scheduledEvents.add(
            _NoteOnPlaybackEvent(
              targetMicros: targetMicros,
              note: playbackEvent.note,
            ),
          );
      }
    }

    scheduledEvents.sort((a, b) {
      final targetCompare = a.targetMicros.compareTo(b.targetMicros);
      if (targetCompare != 0) {
        return targetCompare;
      }
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return scheduledEvents;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restartUnlockTimer?.cancel();
    stop();
    _audioService.dispose();
    super.dispose();
  }
}

sealed class _ScheduledRunEvent {
  const _ScheduledRunEvent({
    required this.targetMicros,
    required this.sortOrder,
  });

  final int targetMicros;
  final int sortOrder;
}

class _NoteOffPlaybackEvent extends _ScheduledRunEvent {
  const _NoteOffPlaybackEvent({required super.targetMicros, required this.note})
    : super(sortOrder: 0);

  final ScheduledPlaybackNote note;
}

class _NoteOnPlaybackEvent extends _ScheduledRunEvent {
  const _NoteOnPlaybackEvent({required super.targetMicros, required this.note})
    : super(sortOrder: 1);

  final ScheduledPlaybackNote note;
}
