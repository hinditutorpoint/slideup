<div align="center">

  <img src="promo_banner.jpg" alt="SlideUp Media Player Banner" width="100%" style="border-radius: 16px; margin-bottom: 20px;" />

  # 🎬 SlideUp Media Player
  ### *Professional All-in-One Media & Document Suite for Android*

  [![Release Build](https://github.com/hinditutorpoint/slideup/actions/workflows/build_release.yml/badge.svg)](https://github.com/hinditutorpoint/slideup/actions/workflows/build_release.yml)
  [![Flutter Version](https://img.shields.io/badge/Flutter-3.29%2B-02569B?logo=flutter)](https://flutter.dev)
  [![Android Support](https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-3DDC84?logo=android)](https://developer.android.com)
  [![License](https://img.shields.io/badge/License-Restricted%20Source--Available-red.svg)](LICENSE)
  [![Live Demo](https://img.shields.io/badge/Web-Live%20Portal-6C63FF?logo=google-chrome)](https://hinditutorpoint.github.io/slideup/)
  [![Promo Video](https://img.shields.io/badge/Video-60FPS%20Showcase-00F0FF?logo=youtube)](https://hinditutorpoint.github.io/slideup/intro_video.html)

  <p align="center">
    <a href="https://hinditutorpoint.github.io/slideup/"><b>Explore Website Portal</b></a> •
    <a href="https://hinditutorpoint.github.io/slideup/intro_video.html"><b>Watch 60FPS Promo Video</b></a> •
    <a href="#-download-release-apks"><b>Download Latest APKs</b></a> •
    <a href="#-key-features"><b>Features</b></a>
  </p>

</div>

---

## 📱 Visual Showcase & Screenshots

<div align="center">

### 🎬 4K Video Player & Floating Picture-in-Picture (PiP)
| 4K Ultra Player | Floating PiP Window | Home & Recent Media |
| :---: | :---: | :---: |
| <img src="screenshots/video-player.png" width="260px" /> | <img src="screenshots/pip-mod.png" width="260px" /> | <img src="screenshots/recent-usage.png" width="260px" /> |

### ✂️ Precision Video Editor & Timeline Tools
| Timeline Trimming | Filters & Speed Ramping | Image Overlays |
| :---: | :---: | :---: |
| <img src="screenshots/video-editor-screen.png" width="260px" /> | <img src="screenshots/video-editor-more-tools.png" width="260px" /> | <img src="screenshots/video-editor-images.png" width="260px" /> |

### 🎵 High-Fidelity Audio Player & 📺 1000+ Live IPTV Channels
| Lossless Music & Equalizer | Live IPTV Player | IPTV Playlists & Categories |
| :---: | :---: | :---: |
| <img src="screenshots/audio-player.png" width="260px" /> | <img src="screenshots/iptv-player.png" width="260px" /> | <img src="screenshots/iptv-playlist.png" width="260px" /> |

### 📚 Document Reader, 🔄 Media Converter & 🌐 Private Browser
| PDF & EPUB Reader | Batch Media Converter | Private Web Browser |
| :---: | :---: | :---: |
| <img src="screenshots/docs.png" width="260px" /> | <img src="screenshots/media-convertor.png" width="260px" /> | <img src="screenshots/private-browser.png" width="260px" /> |

</div>

---

## 🚀 Download Release APKs

Directly compiled and optimized by GitHub Actions Release Pipeline:

| Architecture | Device Compatibility | Download Link |
| :--- | :--- | :---: |
| **ARM64 (v8a)** *(Recommended)* | Modern 64-bit Android smartphones & tablets | [**Download ARM64 APK**](https://github.com/hinditutorpoint/slideup/releases/latest/download/app-arm64-v8a-release.apk) |
| **ARMv7 (32-bit)** | Older 32-bit smartphones and legacy devices | [**Download ARMv7 APK**](https://github.com/hinditutorpoint/slideup/releases/latest/download/app-armeabi-v7a-release.apk) |
| **x86_64** | Android emulators & Windows Subsystem for Android | [**Download x86_64 APK**](https://github.com/hinditutorpoint/slideup/releases/latest/download/app-x86_64-release.apk) |

> 📦 View all releases and changelogs on the [**GitHub Releases Page**](https://github.com/hinditutorpoint/slideup/releases).

---

## ✨ Key Features

### 🎬 1. Advanced 4K Video Player
- **Ultra-Fast Rendering Engine:** Powered by `media_kit` (libmpv backend) for seamless playback of MP4, MKV, AVI, FLV, WEBM, TS, MOV, etc.
- **Smart Dual Gestures:** Swipe left side for Brightness, right side for Volume, horizontal swipe for precision scrubbing.
- **Picture-in-Picture (PiP):** Floating background mini-window (`simple_pip_mode`) while using other apps.
- **Audio & Subtitle Controls:** Multi-audio track switching, external subtitle loader, 0.25x – 4.0x speed regulation, and hardware equalizer.
- **Extraction Tools:** Capture lossless frames (PNG, JPG, BMP) or extract audio tracks into MP3/FLAC.

### ✂️ 2. Integrated Video Editor
- **Precision Trimming & Cutting:** Lossless stream cutting without re-encoding when possible.
- **Video Transformation:** Crop, rotate, flip, and adjust aspect ratios (16:9, 9:16, 1:1, 4:5).
- **Speed Ramping:** Smooth slow motion and fast motion effects.
- **Audio Mixing:** Replace or mix audio tracks with volume control.
- **Visual Filters & Overlays:** Brightness, contrast, saturation, and custom watermark text overlays.

### 🔄 3. Batch Audio & Video Converter
- **Multi-Format Transcoding:** Audio→Audio, Video→Video, and Video→Audio (MP3, AAC, FLAC, WAV, Opus, MP4, MKV, WebM, etc.).
- **Hardware Acceleration:** Auto-detect MediaCodec accelerated encoding.
- **Background Foreground Service:** Converts large media queues reliably in the background with persistent progress notifications.

### 📺 4. Live IPTV & Radio Streaming
- **Multiple Playlist Sources:** Import via M3U URLs, local `.m3u` files, or XTream Codes API.
- **Split Screen Player:** Watch live in the top viewport while exploring categories and channels below.
- **28+ Language Quick-Start:** One-tap presets for Hindi, English, Tamil, Telugu, Bengali, Malayalam, and more.

### 🎵 5. Audio Player & Speaker Suite
- **Lock Screen & Notification Controls:** Full playback controls via `audio_service` and `just_audio`.
- **Sound Equalizer:** 10-band equalizer presets (Rock, Pop, Jazz, Bass Boost) + Speaker Volume Booster.

### 📚 6. Document & E-Book Reader
- **PDF Viewer:** Continuous scroll, text search, page jumping, and bookmarks (`syncfusion_flutter_pdfviewer`).
- **EPUB Reader:** E-book reader with chapter index, font scaling, night mode, and reading progress tracking.
- **TXT Reader:** Distraction-free clean text viewer.

### 🔒 7. Biometric Vault & File Manager
- **Local Authentication:** Lock confidential files using Fingerprint, Face Unlock, or PIN code (`local_auth`).
- **Encrypted Storage:** Sandboxed vault isolated from public gallery scanners.

### 🌐 8. Private Browser
- **Incognito Browsing:** Built-in tracker and ad suppression with direct media downloading.

---

## 🛠️ Technology Stack

| Component | Library / Framework |
| :--- | :--- |
| **Framework** | Flutter 3.29+ / Dart 3.8+ |
| **State Management** | Riverpod (`flutter_riverpod`) |
| **Video Engine** | MediaKit (`media_kit`, `media_kit_video`, `libmpv`) |
| **Video Processing** | FFmpeg Kit (`ffmpeg_kit_flutter_new`) |
| **Audio Engine** | JustAudio & AudioService (`just_audio`, `audio_service`) |
| **PDF & Documents** | Syncfusion PDF Viewer (`syncfusion_flutter_pdfviewer`) |
| **Storage & Database** | SQLite (`sqflite`), Hive (`hive_flutter`), SecureStorage |
| **Security & Auth** | LocalAuth (`local_auth`), Crypto (`crypto`) |

---

## 📜 License & Intellectual Property

Copyright (c) 2026 SlideUp Project (hinditutorpoint). All rights reserved.

This project is licensed under a **Restricted Source-Available License**. You are permitted to inspect, evaluate, and learn from the source code for personal and educational purposes, but you may **NOT** clone, re-brand, distribute, or publish this software on any app store without express written authorization. See the [LICENSE](LICENSE) file for complete terms.
