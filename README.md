# Tap Score

A lightweight, mobile-first score editor and playback tool built with Flutter. Designed to make music notation accessible — quickly jot down single-staff melodies with immediate audio feedback, no complex setup required.

## Features

- **Piano keyboard input** — tap notes on a visual keyboard to build melodies
- **Playback** — hear your score instantly with cursor tracking
- **Note durations** — whole through thirty-second notes and rests
- **Notation editing** — dot, triplet, and forward slur shortcuts in the editor
- **Time signatures** — 2/4, 3/4, 4/4, 3/8, 6/8, 5/4, 7/8, 12/8
- **Key signatures** — all 13 major keys with automatic accidentals, circle-of-fifths navigation
- **Professional rendering** — powered by VexFlow
- **Cross-platform** — Android, iPad, and Web

## Getting Started

Requires Flutter 3.10+.

```bash
# Web
flutter run -d chrome

# Cloudflare preview wasm build
./tool/cloudflare_pages_build_wasm_preview.sh

# Android
flutter run -d android

# iOS
flutter run -d ios
```

## Local Development

### Android emulator on this machine

Verified on this macOS setup:

- Available AVD: `Pixel_9_Pro_XL_API_36`
- Start emulator: `flutter emulators --launch Pixel_9_Pro_XL_API_36`
- Confirm device: `flutter devices`
- Run app on emulator: `flutter run -d emulator-5554`

If the emulator has just been launched, wait until `flutter devices` shows `emulator-5554` as an Android device before running the app.

## Deploy To Cloudflare Pages

This project can be deployed on Cloudflare's free Pages plan as a static Flutter Web site.

### Recommended setup

1. Push this repository to GitHub.
2. In Cloudflare, create a new Pages project and connect the repository.
3. Use these build settings:

```text
Framework preset: None
Build command: ./tool/cloudflare_pages_build.sh
Build output directory: build/web
Root directory: /
```

The production build script downloads and pins Flutter 3.38.1, enables web support, runs `flutter pub get`, and builds the JS/CanvasKit app for Pages.

### Wasm preview setup

Use this build command for a preview-only experiment:

```text
Build command: ./tool/cloudflare_pages_build_wasm_preview.sh
Build output directory: build/web
```

Keep the production site on `./tool/cloudflare_pages_build.sh` until the wasm preview proves faster and stable enough to replace it.

### Why this setup

- Cloudflare Pages does not provide Flutter by default.
- The build script keeps the deployment reproducible by pinning the Flutter SDK version used by this project.
- UI fonts are bundled locally so Flutter Web does not need Google font fallback requests to render the main interface.
- `web/_redirects` enables SPA fallback so direct requests still resolve to `index.html`.

### First deployment checklist

1. In Cloudflare Pages, ensure the production branch points to your main branch.
2. Trigger the first deploy.
3. If you want a custom domain, add it in Pages after the first successful build.

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
