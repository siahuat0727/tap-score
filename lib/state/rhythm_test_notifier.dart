import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/score.dart';
import '../rhythm_test/rhythm_matcher.dart';
import '../rhythm_test/rhythm_test_models.dart';
import '../rhythm_test/rhythm_timeline_builder.dart';
import '../services/audio_service.dart';

enum RhythmTestPhase { idle, countIn, running, finished, cancelled }

class RhythmTestNotifier extends ChangeNotifier {
  RhythmTestNotifier({
    required Score score,
    AudioService? audioService,
    RhythmTimelineBuilder? timelineBuilder,
    RhythmMatcher? matcher,
    Stopwatch Function()? createStopwatch,
  }) : _score = score.copy(),
       _audioService = audioService ?? AudioService(),
       _timelineBuilder = timelineBuilder ?? const RhythmTimelineBuilder(),
       _matcher = matcher ?? const RhythmMatcher(),
       _createStopwatch = createStopwatch ?? Stopwatch.new {
    _timeline = _timelineBuilder.build(_score);
  }

  final Score _score;
  final AudioService _audioService;
  final RhythmTimelineBuilder _timelineBuilder;
  final RhythmMatcher _matcher;
  final Stopwatch Function() _createStopwatch;

  late RhythmTimeline _timeline;

  RhythmTestPhase _phase = RhythmTestPhase.idle;
  bool _isInitialized = false;
  String? _errorMessage;
  RhythmTestResult? _result;
  final List<TapInputEvent> _tapEvents = [];
  int _nextTapId = 0;
  int _sessionId = 0;
  Stopwatch? _sessionStopwatch;
  int? _performanceStartMicros;
  int? _countInPulseIndex;
  int? _runningPulseIndex;
  double _elapsedRunSeconds = 0;
  double _playheadTimeSeconds = 0;
  final double _postRollPulseCount = 1.0;

  Score get score => _score;

  RhythmTimeline get timeline => _timeline;

  RhythmTestPhase get phase => _phase;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  RhythmTestResult? get result => _result;

  List<TapInputEvent> get tapEvents => List.unmodifiable(_tapEvents);

  RhythmOverlayRenderData get overlayRenderData {
    final resultTapEvents = [
      if (_result != null) ...[
        for (final pair in _result!.matchedPairs) pair.tap,
        ..._result!.unmatchedTapEvents,
      ],
    ]..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));

    return RhythmOverlayRenderData(
      showExpectedEvents: _phase == RhythmTestPhase.finished,
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
      matchedPairs: _result?.matchedPairs ?? const <MatchedRhythmPair>[],
      appliedShiftSeconds: _result?.appliedShiftSeconds ?? 0,
    );
  }

  int? get countInPulseIndex => _countInPulseIndex;

  int? get runningPulseIndex => _runningPulseIndex;

  double get elapsedRunSeconds => _elapsedRunSeconds;

  double get playheadTimeSeconds => _playheadTimeSeconds;

  bool get showsExpectedAnswers => _phase == RhythmTestPhase.finished;

  bool get isBusy =>
      _phase == RhythmTestPhase.countIn || _phase == RhythmTestPhase.running;

  bool get canStart =>
      !isBusy &&
      _errorMessage == null &&
      _isInitialized &&
      _timeline.expectedEvents.isNotEmpty;

  Future<void> init() async {
    if (_isInitialized || _errorMessage != null) {
      notifyListeners();
      return;
    }

    final initialized = await _audioService.init();
    if (!initialized) {
      _errorMessage =
          'Rhythm test metronome is unavailable on this platform or audio failed to initialize.';
      notifyListeners();
      return;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> start() async {
    if (isBusy) {
      return;
    }

    if (_timeline.expectedEvents.isEmpty) {
      _errorMessage = 'Rhythm test needs at least one non-rest note onset.';
      notifyListeners();
      return;
    }

    if (!_isInitialized) {
      await init();
      if (!_isInitialized) {
        return;
      }
    }

    _sessionId += 1;
    _clearSessionData();
    _countInPulseIndex = 0;
    _runningPulseIndex = null;
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = -_timeline.countInDurationSeconds;
    _phase = RhythmTestPhase.countIn;
    notifyListeners();

    unawaited(_runSession(_sessionId));
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
    notifyListeners();
  }

  void stop() {
    if (_phase == RhythmTestPhase.idle) {
      return;
    }

    _sessionId += 1;
    _sessionStopwatch?.stop();
    _phase = RhythmTestPhase.cancelled;
    _countInPulseIndex = null;
    _runningPulseIndex = null;
    _playheadTimeSeconds = 0;
    notifyListeners();
  }

  void reset() {
    if (isBusy) {
      return;
    }

    _phase = RhythmTestPhase.idle;
    _countInPulseIndex = null;
    _runningPulseIndex = null;
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = 0;
    _clearSessionData();
    notifyListeners();
  }

  void setTempo(double bpm) {
    if (isBusy) {
      return;
    }

    _score.bpm = bpm.clamp(40, 240);
    _timeline = _timelineBuilder.build(_score);
    _phase = RhythmTestPhase.idle;
    _countInPulseIndex = null;
    _runningPulseIndex = null;
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = 0;
    _clearSessionData();
    notifyListeners();
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
      _audioService.playMetronomeClick(accented: index == 0);
      notifyListeners();
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
    _elapsedRunSeconds = 0;
    _playheadTimeSeconds = 0;
    notifyListeners();

    final runPulseCount =
        (_timeline.totalDurationSeconds / _timeline.pulseDurationSeconds)
            .ceil();
    for (var index = 0; index < runPulseCount; index++) {
      final targetMicros = performanceStartMicros + (index * pulseMicros);
      if (!await _waitUntil(
        stopwatch: stopwatch,
        sessionId: sessionId,
        targetMicros: targetMicros,
      )) {
        return;
      }

      _runningPulseIndex = index;
      _syncPlaybackProgress(stopwatch);
      _audioService.playMetronomeClick(
        accented: index % _timeline.pulsesPerMeasure == 0,
      );
      notifyListeners();
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
    notifyListeners();

    final graceMicros = (pulseMicros * _postRollPulseCount).round();
    if (!await _waitUntil(
      stopwatch: stopwatch,
      sessionId: sessionId,
      targetMicros: finishMicros + graceMicros,
    )) {
      return;
    }

    _sessionStopwatch?.stop();
    _completeRun();
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
    if ((nextPlayhead - _playheadTimeSeconds).abs() < 0.001 &&
        (nextElapsed - _elapsedRunSeconds).abs() < 0.001) {
      return;
    }

    _playheadTimeSeconds = nextPlayhead;
    _elapsedRunSeconds = nextElapsed;
    notifyListeners();
  }

  void _completeRun() {
    _phase = RhythmTestPhase.finished;
    _runningPulseIndex = null;
    _countInPulseIndex = null;
    _result = _matcher.match(
      expectedEvents: _timeline.expectedEvents,
      tapEvents: _tapEvents,
      matchingWindowSeconds: _timeline.matchingWindowSeconds,
    );
    notifyListeners();
  }

  void _clearSessionData() {
    _result = null;
    _tapEvents.clear();
    _nextTapId = 0;
    _performanceStartMicros = null;
    _sessionStopwatch = null;
    _playheadTimeSeconds = 0;
  }

  @override
  void dispose() {
    stop();
    _audioService.dispose();
    super.dispose();
  }
}
