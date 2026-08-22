# Contributing to SlideUp

Thank you for your interest in contributing to **SlideUp Media Player & Video Editor**! We welcome contributions from developers, designers, and enthusiasts who want to help make SlideUp a best-in-class open-source media player and video editing suite.

---

## 📋 Table of Contents
- [Code of Conduct](#-code-of-conduct)
- [How to Contribute](#-how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Submitting Pull Requests](#submitting-pull-requests)
- [Development Setup](#-development-setup)
- [Project Structure](#-project-structure)
- [Coding Guidelines](#-coding-guidelines)
- [Branching & Commit Guidelines](#-branching--commit-guidelines)
- [License Notice](#-license-notice)

---

## 📜 Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free experience for everyone. Please be respectful, constructive, and collaborative in all interactions across issues, pull requests, and discussions.

---

## 🛠️ How to Contribute

### Reporting Bugs
If you find a bug or unexpected behavior:
1. **Search existing issues** to ensure the bug hasn't already been reported.
2. Open a new issue with a clear and descriptive title.
3. Provide details including:
   - Your device model and Android version.
   - Flutter version (`flutter --version`).
   - Steps to reproduce the issue.
   - Expected vs actual behavior.
   - Stack traces / logs / screenshots if available.

### Suggesting Features
Feature proposals are always welcome! When opening a feature request, please describe:
- The problem or use-case you are trying to solve.
- Your proposed solution or desired behavior.
- Any alternative solutions considered.

### Submitting Pull Requests
1. **Fork** the repository and create your branch from `main`.
2. Ensure your code follows the project's [Coding Guidelines](#-coding-guidelines).
3. Verify that the project analyzes with zero issues:
   ```bash
   flutter analyze
   ```
4. Test your changes on an emulator or physical device.
5. Push to your fork and submit a Pull Request targeting `main`.
6. Describe the changes in detail in your PR description.

---

## 💻 Development Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`3.29.0` or higher recommended)
- [Dart SDK](https://dart.dev/get-dart) (`3.8.0` or higher)
- Android Studio / VS Code with Flutter and Dart plugins
- Android SDK with NDK installed
- A physical Android device or emulator (API 26+)

### Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hinditutorpoint/slideup.git
   cd slideup/slideup
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code generation (if applicable):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```
lib/
├── core/                  # Core utilities, theme, constants, and database
├── features/              # Feature modules
│   ├── audio_player/      # Audio playback and equalizer
│   ├── browser/           # Built-in private browser
│   ├── converter/         # Batch media converter (video/audio)
│   ├── document_reader/   # PDF, EPUB, TXT reader
│   ├── iptv/              # Live IPTV streaming & M3U parsing
│   ├── vault/             # Biometric-secured media vault
│   └── video_editor/      # Complete Reel & Video Editor Suite
│       ├── components/    # Video editor UI components & canvas
│       ├── models/        # Data models & state representations
│       ├── panels/        # Collapsible editing panels & toolbars
│       ├── providers/     # State management (Riverpod)
│       ├── services/      # Video processing, FFmpeg, audio sync, AI
│       ├── sheets/        # Modal bottom sheets for tools & pickers
│       └── tabs/          # Bottom navigation tabs for editing tools
├── models/                # Shared data models
├── providers/             # Global app providers
├── screens/               # Main screens and navigation
├── services/              # Common application services
└── widgets/               # Shared reusable UI widgets
```

---

## 📐 Coding Guidelines

1. **State Management**: We use [Riverpod](https://riverpod.dev/) for state management. Ensure providers are scoped cleanly and state is immutable where applicable.
2. **Formatting & Linting**: Follow official Dart guidelines. Run `flutter format .` and `flutter analyze` before committing.
3. **No Memory Leaks**:
   - Always dispose controllers (`TextEditingController`, `ScrollController`, `TabController`, `AnimationController`, etc.) in `dispose()`.
   - Avoid creating new controllers directly inside `build()` methods.
4. **Defensive Layouts**:
   - Prevent `RenderFlex` overflows by utilizing flexible wrappers (`SingleChildScrollView`, `Expanded`, `Flexible`, `FittedBox`).
   - Clamp numeric inputs (sliders, durations) to prevent `AssertionError` crashes.

---

## 🌿 Branching & Commit Guidelines

- **Branch naming convention**:
  - `feat/feature-name` for new features
  - `fix/bug-name` for bug fixes
  - `refactor/component-name` for code refactoring
  - `docs/doc-update` for documentation changes
- **Commit messages**:
  - Write clear, imperative commit messages (e.g., `feat: add audio equalizer preset selector` or `fix: resolve slider value clamping on trim panel`).

---

## ⚖️ License Notice

By contributing to SlideUp, you agree that your contributions will be licensed under the project's [Restricted Source-Available License](LICENSE).
