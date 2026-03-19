# Tap Score

A lightweight, mobile-first score editor and playback tool built with Flutter. Designed to make music notation accessible — quickly jot down single-staff melodies with immediate audio feedback, no complex setup required.

## Features

- **Piano keyboard input** — tap notes on a visual keyboard to build melodies
- **Playback** — hear your score instantly with cursor tracking
- **Note durations** — whole, half, quarter, eighth, sixteenth notes and rests
- **Time signatures** — 2/4, 3/4, 4/4, 3/8, 6/8, 5/4, 7/8, 12/8
- **Key signatures** — all 13 major keys with automatic accidentals, circle-of-fifths navigation
- **Professional rendering** — powered by VexFlow
- **Cross-platform** — Android, iPad, and Web

## Getting Started

Requires Flutter 3.10+.

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

## Architecture

```
lib/
├── main.dart              # App entry, Provider setup
├── screens/               # Score editor screen
├── models/                # Score, Note, KeySignature, enums
├── state/                 # ScoreNotifier (ChangeNotifier + Provider)
├── services/              # Audio (flutter_midi_pro / Web Audio API)
└── widgets/               # Piano keyboard, VexFlow renderer, playback controls
```

Score rendering uses VexFlow via WebView (native) or iframe (web). Audio uses `flutter_midi_pro` with a SoundFont on native platforms and the Web Audio API on web.
