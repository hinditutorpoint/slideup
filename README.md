# SlideUp — Professional All-in-One Media & Document Suite

SlideUp is a feature-rich, high-performance multimedia player, document reader, video editor, and file manager built with **Flutter**, **Riverpod**, **MediaKit**, and **FFmpeg**. It delivers an ultra-smooth, customizable experience for playing videos and audios, editing media, reading documents (PDF, EPUB, TXT), private browsing, and securing private files.

---

## ✨ Key Features

### 🎬 Advanced Video Player
- **High Performance Engine**: Powered by `media_kit` (libmpv backend) for seamless playback of virtually all formats (MP4, MKV, AVI, FLV, WEBM, TS, MOV, etc.).
- **Smart Gestures**: Dual-side swipe controls for screen brightness, volume, and intuitive scrubbing/seeking.
- **Picture-in-Picture (PiP)**: Native floating mini-player support (`simple_pip_mode`).
- **Audio & Subtitle Controls**: Multi-audio track switching, external subtitle loader, playback speed regulation (0.25x – 4.0x), aspect ratio adjustments, and sleep timer.
- **Hardware Acceleration & Equalizer**: Native audio enhancement and equalizer tuning.
- **Media Extraction Tools**:
  - **Screenshot Capture**: Snapshot video frames directly in PNG, JPG, BMP, or WebP.
  - **Audio Extractor**: Convert video to MP3, AAC, WAV, or FLAC.
  - **Frame Extractor**: Extract sequence frames at custom FPS.

---

### ✂️ Integrated Video Editor
- **Timeline Trimming & Cutting**: Fast precision trim and cut without re-encoding when possible.
- **Video Transformation**: Crop, rotate, flip, and adjust aspect ratios (16:9, 9:16, 1:1, 4:5, etc.).
- **Speed Ramping**: Slow motion and fast motion video effects.
- **Audio Mixing & Replacement**: Add background music, replace existing audio, adjust volume levels.
- **Visual Filters & Adjustments**: Adjust brightness, contrast, saturation, and apply color presets.
- **Text & Watermark Overlays**: Custom text styling, positioning, and timestamps.
- **FFmpeg Powered**: Accelerated rendering and export via `ffmpeg_kit_flutter_new`.

---

### 🔄 Enhanced Audio/Video Converter
- **Broad Format Support**: Convert audio→audio, video→video, and video→audio (MP3, M4A/AAC, FLAC, WAV, Opus, OGG, MP4, MKV, AVI, WebM, MOV, MPG, TS, FLV, and more).
- **Smart Presets**: 12 built-in presets (MP3 High Quality, FLAC Lossless, MP4 H.264 1080p, WebM VP9, MKV HEVC, etc.) plus custom presets you can create, edit, duplicate, rename, delete, and mark as default.
- **Advanced Options**: Video codec (H.264, HEVC, AV1, VP8/VP9), resolution, frame rate, bitrate, CRF, encoder preset & profile, pixel format, audio codec/bitrate/sample rate/channels/quality/volume, container format, metadata preservation, and FastStart.
- **Real Progress & Media Info**: Live FFmpeg statistics (time, speed, size) with FFprobe-powered source analysis — no fake progress bars.
- **Batch Queue & Background Conversion**: Multiple independent jobs, persistent queue with retry/cancel, and an Android Foreground Service notification with live progress and Cancel/Open actions.
- **Output Management**: Same folder / app folder / user-selected folder, smart output naming (`movie.mkv → movie.mp4`), and duplicate handling (replace, rename `movie (1).mp4`, skip, ask).
- **Conversion History**: Search and filter past jobs by status, retry or reconvert, open/delete outputs, and view full FFmpeg logs.
- **Hardware Acceleration**: Auto-detect MediaCodec-accelerated encoding (Auto / CPU / Hardware modes).
- **Powered by FFmpeg**: Built on `ffmpeg_kit_flutter_new` with `flutter_foreground_task` for reliable background conversion.

---

### 📺 IPTV & Live TV
- **Multiple Playlist Sources**: Add playlists from an **M3U URL**, a **local .m3u file**, or an **XTream Codes** API (server + username + password).
- **YouTube-Style Browsing**: Responsive channel grid/list with category chips, search, favorites filter, and live/radio badges.
- **Language Quick-Start**: 28 one-tap language playlists (Hindi, English, Tamil, Telugu, Kannada, Malayalam, Bengali, etc.) from the public `iptv-org` catalog.
- **Built-in Sample Playlist**: Load a ready-to-test public playlist with a single tap.
- **Split Player Screen**: Watch live in the top player while browsing and switching channels from the list below — no need to leave the player.
- **Video & Radio Channels**: Video streams play via `media_kit`; audio-only channels play through the background audio suite (`just_audio` + mini player).
- **Favorites & Persistence**: Channels and playlists are persisted locally (sqflite) with per-channel favorites and swipe-to-delete playlists.

---

### 🎵 Comprehensive Audio Player & Speaker Suite
- **Background Playback & Lock Screen Controls**: Powered by `just_audio` and `audio_service` with notification media controls.
- **Speaker Booster Player**: Built-in sound amplifier and loudness enhancer.
- **Queue & Playlists**: Create, reorder, and persist custom playlists and favorites.
- **Sleep Timer & Equalizer**: 10-band equalizer presets (Rock, Pop, Jazz, Classical, Bass Boost, etc.) and auto-off timer.

---

### 📚 Document & E-Book Reader
- **PDF Viewer & Annotation**: Powered by `syncfusion_flutter_pdfviewer` with text search, page jumping, continuous scroll, and bookmarks.
- **EPUB Reader**: Interactive e-book reader with chapter navigation, font scaling, night mode, and reading history.
- **TXT & Code Reader**: Lightweight, distraction-free text and script document viewer.
- **Reading History & Tracker**: Automatically bookmark reading progress across all documents.

---

### 🔒 Secure Vault (Locked Files)
- **Biometric & PIN Lock**: Protect sensitive videos, audios, and documents using fingerprint, face unlock, or PIN code (`local_auth`).
- **Encrypted Storage**: Secure credential and key management (`flutter_secure_storage` & `crypto`).
- **Stealth / Sandboxed Folder**: Keep hidden files isolated from public gallery scans.

---

### 🌐 Private Browser & Media Downloader
- **Incognito Web Browser**: Built-in `flutter_inappwebview` with tracking protection, tab management, and ad/pop-up suppression.
- **Download Manager**: Multi-threaded download engine with pause, resume, background downloads (`workmanager`), and download progress indicators.

---

### 📁 Smart File Browser & Backup
- **Deep Category Browsing**: Categorize files by Video, Audio, Documents, Images, Downloads, and Extracted Media.
- **Batch Operations**: Bulk delete, share, rename, move, and favorite.
- **Backup & Restore**: Export and import application settings, playlists, and reading history (`hive_flutter` & `sqflite`).

---

### 🎙️ On-Device AI Subtitles & Transcription
- **Offline Speech Recognition**: Local on-device AI transcription powered by `sherpa_onnx` (no internet required for speech processing).

---

## 🛠️ Technology Stack

| Category | Technologies / Libraries |
|---|---|
| **Framework** | Flutter (Dart SDK ^3.8.1) |
| **State Management** | Flutter Riverpod (`flutter_riverpod: ^3.0.3`) |
| **Media Playback** | `media_kit`, `video_player`, `just_audio`, `audio_service` |
| **Video Processing** | `ffmpeg_kit_flutter_new`, `image`, `saver_gallery` |
| **Media Conversion** | `ffmpeg_kit_flutter_new` (FFprobe), `flutter_foreground_task`, `disk_space_plus`, `file_picker` |
| **Documents** | `syncfusion_flutter_pdfviewer`, `syncfusion_flutter_pdf`, `open_filex` |
| **Security & Auth** | `local_auth`, `flutter_secure_storage`, `crypto` |
| **Browser & Network** | `flutter_inappwebview`, `dio`, `http`, `connectivity_plus` |
| **Local Storage** | `hive_flutter`, `sqflite`, `path_provider` |
| **AI / ML** | `sherpa_onnx` (Offline ASR / Speech Recognition) |
| **UI & Animations** | `curved_navigation_bar`, `flutter_slidable`, `shimmer`, `loading_animation_widget` |

---

## 📁 Project Structure

```
slideup/
├── android/                   # Android native configuration (Gradle Kotlin DSL)
├── assets/                    # Static assets, icons, fonts, and images
│   ├── icons/
│   └── images/
├── lib/
│   ├── core/                  # Core constants, themes, database helpers
│   ├── features/              # Modular feature domains
│   │   ├── documents/         # PDF reader, search, annotations & history
│   │   ├── converter/         # Audio/video converter: queue, presets, history & FFmpeg runner
│   │   ├── iptv/              # IPTV: M3U/XTream playlists, channel grid, split player screen
│   │   ├── epub_reader/       # EPUB reader engine
│   │   ├── private_browser/   # In-app browser & download manager
│   │   ├── speaker_player/    # Audio amplifier & loudness booster
│   │   ├── txt_reader/        # Text file reader
│   │   ├── video_editor/      # Video trimming, filters, timeline & export
│   │   ├── video_player/      # Video player components & gestures
│   │   └── video_search/      # Media search and discovery
│   ├── helpers/               # Utility functions & helpers
│   ├── models/                # Data models & entities
│   ├── providers/             # Riverpod state providers
│   ├── screens/               # Main application screens & navigation
│   ├── services/              # Background, audio, video & storage services
│   ├── shared/                # Shared widgets, dialogs, and components
│   └── main.dart              # App entry point
└── pubspec.yaml               # Project dependencies and asset definitions
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version `>= 3.8.1`)
- [Android Studio](https://developer.android.com/studio) / Android SDK (API Level 24+ recommended)
- Java Development Kit (JDK 11 or 17)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/slideup.git
   cd slideup
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Compile-Time Environment Variables (Optional)**:
   To enable online API services or image/translation features, pass the compile-time variables:
   ```bash
   flutter run \
     --dart-define=API_BASE_URL=https://your-api-url \
     --dart-define=API_KEY=your-api-key \
     --dart-define=PIXABAY_KEY=your-pixabay-key
   ```

4. **Build APK / Run Debug**:
   ```bash
   # Run on connected device
   flutter run

   # Build Release APK
   flutter build apk --release
   ```

---

## 🔐 Permissions Overview

SlideUp requests only essential Android permissions:
- `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`: To index and play local media files.
- `WRITE_EXTERNAL_STORAGE` (Android <= 10): To save edited videos, screenshots, and extracted audio.
- `USE_BIOMETRIC` / `USE_FINGERPRINT`: To secure the Private Vault.
- `INTERNET`: For the private in-app web browser and downloading online media.
- `WAKE_LOCK` & `FOREGROUND_SERVICE`: For uninterrupted background audio and video playback.
- `FOREGROUND_SERVICE_MEDIA_PROCESSING`: For reliable background media conversion with a persistent progress notification.
- `SYSTEM_ALERT_WINDOW`: For Picture-in-Picture (PiP) window overlay.

---

## 📄 License & Intellectual Property

Copyright (c) 2026 SlideUp Project (hinditutorpoint). All rights reserved.

This project is licensed under a **Restricted Source-Available License**. You may inspect and evaluate the source code for personal and educational purposes, but you may **NOT** clone, re-brand, distribute, or publish this software on any app store (Google Play, OPPO App Market, etc.) without express written permission. See the [LICENSE](file:///D:/flutterapp/slideup/slideup/LICENSE) file for complete terms.
