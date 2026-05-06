# Score Notifier Controller Split Design

Date: 2026-05-06

## Context

`ScoreNotifier` is the widget-facing state object for the compose workspace. It has grown to own several different responsibilities:

- score editing commands, selection, cursor, toolbar state, and keyboard input state
- workspace loading, draft persistence, saved score and preset metadata, imports, deletes, and library messages
- compose playback, audio initialization state, note preview, and playback highlighting

The project guidance prefers one concept, one architecture; replacement over wrapping; and removal of obsolete duplicate abstractions. The refactor should therefore remove `ScoreNotifier` from widget usage instead of keeping it as a long-term facade.

## Goal

Replace `ScoreNotifier` as a widget-facing API with focused controllers that share one score/workspace state owner. The result should keep the current user behavior while making controller boundaries explicit in production code and tests.

## Non-Goals

- Do not redesign the workspace UI.
- Do not change score storage formats.
- Do not change renderer payload semantics except for imports needed by the new controllers.
- Do not add a second architecture beside `ScoreNotifier`; the refactor is complete only when widgets no longer import or depend on `ScoreNotifier`.

## Architecture

Introduce `EditableScoreSession` as the single owner of the current mutable score and loaded workspace metadata. It exposes the current `Score`, current `WorkspaceSession`, saved/preset catalogs, active document labels, and unsaved-state derivation.

Introduce three widget-facing controllers:

- `EditorController`: owns editing state and commands.
- `PlaybackController`: owns compose playback, audio status, playback index, and note preview.
- `ScoreLibraryController`: owns workspace load/save/delete/import/restore, draft persistence, portable document creation, and library messages.

Widgets should depend on the narrow controller they need. `ScoreNotifier` should be deleted after migration, not retained as a compatibility facade.

## Data Flow

`EditableScoreSession` owns:

- `score`: the mutable editor score
- `workspace`: the loaded document metadata and saved/preset catalogs
- `hasUnsavedChanges`: derived from `score != workspace.document.score`
- `replaceWorkspace(...)`: applied after load/save/import/delete
- `markScoreChanged()`: updates derived dirty state and notifies listeners

`EditorController` mutates `EditableScoreSession.score` and marks score changes after successful edits. It does not own repository operations or long-running audio playback.

`PlaybackController` reads `EditableScoreSession.score` for playback and preview. It owns `AudioService`, `AudioStatus`, `isPlaying`, `playbackIndex`, `play()`, `stop()`, and a note preview method used by editor interactions.

`ScoreLibraryController` calls `WorkspaceRepository` and updates `EditableScoreSession` with returned `WorkspaceSession` values. It also owns user-facing library messages and draft-save scheduling. Draft persistence is triggered by listening to score-change notifications from `EditableScoreSession`; the session does not call repositories directly.

`WorkspaceStartupController` should receive the specific collaborators it needs instead of a `ScoreNotifier`: `ScoreLibraryController` for initial load, `EditableScoreSession` for current score/reference metadata, and `PlaybackController` where compose playback must be stopped before rhythm-test startup.

## Component Boundaries

Add these files:

- `lib/state/editable_score_session.dart`
- `lib/state/editor_controller.dart`
- `lib/state/playback_controller.dart`
- `lib/state/score_library_controller.dart`

Move behavior from `ScoreNotifier` by ownership:

- `EditorController`: selection kind, selected index, cursor index, current duration, rest/dot/slur/triplet modes, keyboard input mode, keyboard octave shift, toolbar derived state, note insertion/deletion, triplet creation, slur sanitation, clef/key/time/tempo edits, shortcut handling.
- `PlaybackController`: audio service ownership, audio state sync, score playback, stop behavior, playback index updates, note preview used by note insertion/selection/pitch edits.
- `ScoreLibraryController`: initial workspace load, draft restore, save current score, load saved score, load preset score, import document, delete saved score, build portable document, initial load flags, library messages, draft persistence scheduling.
- `EditableScoreSession`: score replacement, workspace replacement, active saved/preset lookup, current score label, reference BPM, unsaved-state calculation.

Update widget dependencies:

- `ScoreViewWidget`, `DurationSelector`, `PianoKeyboard`, and signature pickers use `EditorController` plus `EditableScoreSession`.
- Compose play controls and playback highlighting use `PlaybackController`.
- `WorkspaceTopBar`, save dialog, export flow, and library toast use `ScoreLibraryController`.
- `WorkspaceStartupController` uses `ScoreLibraryController`, `EditableScoreSession`, and `PlaybackController`.
- Router/provider setup creates one `EditableScoreSession` and the three controllers for each workspace page.

## Error Handling

Keep invalid caller behavior explicit:

- Invalid saved or preset IDs throw instead of becoming silent no-ops.
- Empty save names remain user-facing validation errors in `ScoreLibraryController`.
- Storage and preset load failures become explicit library messages.
- Audio initialization failures remain explicit in `PlaybackController.audioStatus`.
- UI-disabled editor commands can return early, but invalid indexes that indicate a bad caller should throw rather than silently falling back.

## Testing

Replace broad `ScoreNotifier` tests with controller-specific tests:

- `test/state/editor_controller_test.dart`: selection, insertion, rest/dot/slur/triplet behavior, keyboard mode, metadata edits, and fail-fast invalid edit cases.
- `test/state/score_library_controller_test.dart`: load/restore/save/load saved/load preset/import/delete, baseline and unsaved state, messages, and draft persistence scheduling.
- `test/state/playback_controller_test.dart`: play/stop, playback index changes, audio status sync, and note preview.

Update widget, router, startup, and renderer tests to construct the new shared session and controllers. Add a focused assertion or tooling test that widgets no longer import `ScoreNotifier` once migration is complete.

## Verification

After implementation, run:

```bash
flutter analyze
flutter test
flutter run -d chrome
```

Use the Chrome run for a manual smoke test of workspace startup, note input, save/load, playback, and rhythm-test entry.
