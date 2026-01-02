# Slideup Media Player - AI Coding Guidelines

## Architecture Overview

**Slideup** is a professional Flutter media player supporting video, audio, documents, and PDFs with advanced features (screenshots, audio extraction, frame extraction, playlists).

### Core Layers
- **Services**: Singleton pattern for business logic (DatabaseService, VideoService, FileScannerService, PermissionService, AudioService)
- **Providers**: Riverpod state management (MediaNotifier, PlaylistNotifier, SettingsNotifier) - async state with loading/error handling
- **Models**: Dart dataclasses (MediaFile, Playlist, RecentFile) stored in SQLite
- **Screens**: Material widgets using edge-to-edge design with dark theme (AppTheme.darkTheme)
- **Widgets**: Reusable UI components (player controls, file browsers, sliders)

### Key Dependencies
- **State Management**: flutter_riverpod v3.0.3 with AsyncValue pattern
- **Database**: SQLite (sqflite) with WAL mode for concurrency
- **Media**: ffmpeg_kit_flutter_new, just_audio, video_player, chewie, pod_player
- **File I/O**: path_provider (app docs directory), file_picker, saver_gallery
- **Security**: flutter_secure_storage, encrypt, local_auth

## Data Flow Pattern

```
User Action → Notifier (Provider) → Service (singleton) → Database/FFmpeg/FileSystem
                    ↓
               AsyncValue updates UI
```

**Always use providers** for UI state updates; never fetch data directly in widgets. Services handle the actual work; providers orchestrate it.

## Project-Specific Patterns

### File Organization Convention
Files are organized under `AppDocumentsDirectory/files/`:
- `screenshots/` - Captured frames (PNG, JPG, BMP, WebP)
- `audio/` - Extracted audio (MP3, AAC, WAV, FLAC)
- `frames/` - Timestamped subdirectories of extracted frames (JPG, PNG, BMP, WebP)

Always use the `VideoService._getScreenshotsDirectory()`, `_getAudioDirectory()`, `_getFramesDirectory()` helpers. Organize extracted files by type in subdirectories.

### Notifier Pattern with Error Handling
```dart
class ExampleNotifier extends Notifier<AsyncValue<Data>> {
  @override
  AsyncValue<Data> build() => const AsyncValue.loading();
  
  Future<void> doWork() async {
    state = const AsyncValue.loading();
    try {
      // fetch/process data
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow; // Optional: let caller handle
    }
  }
}
```

### Database Operations
- Use `DatabaseService.instance` (singleton)
- All queries are async; use Futures
- Enable WAL mode is default (better concurrency)
- Tables: media_files, playlists, playlist_items, recent_files

### FFmpeg Integration
Use `VideoService` methods for media operations:
- `captureScreenshot(videoPath, time, format)` - screenshots
- `extractAudio(videoPath, format, outputPath)` - audio extraction
- `extractFrames(videoPath, fps, format, outputPath)` - frame extraction
- Always save to organized directories; handle SaverGallery for gallery access

## Critical Workflows

### Running the App
```bash
flutter pub get
flutter run -d <device-id>
```

### Building
```bash
flutter build apk    # Android
flutter build ipa    # iOS
```

### Database Debugging
- SQLite file location: `<app-docs>/slideup_media.db`
- Use sqflite's `rawQuery()` for custom queries
- Migrations use `onUpgrade` callback (version parameter in openDatabase)

### Permission Handling
Always call `PermissionService.instance.hasAllPermissions()` before file operations. Request via `requestPermissions()` if denied.

## UI/Styling Conventions

- **Theme**: Dark-only (`AppTheme.darkTheme`, colors use `0xFF1A1A2E`, `0xFF16213E`)
- **System UI**: Edge-to-edge design; status bar & nav bar styled in main.dart
- **Text Scaling**: Fixed at 1.0 (via MediaQuery override) to prevent layout issues
- **Orientation**: All modes supported (portrait, landscape)

## Important Files to Know

- [main.dart](main.dart) - App initialization, Hive setup, SystemChrome config
- [lib/core/utils/safe_async.dart](lib/core/utils/safe_async.dart) - Async function wrap when need 
- [lib/services/video_service.dart](lib/services/video_service.dart) - FFmpeg wrapper, file organization
- [lib/services/database_service.dart](lib/services/database_service.dart) - SQLite setup, schema
- [lib/providers/media_provider.dart](lib/providers/media_provider.dart) - Media scanning & storage notifier
- [lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart) - Color & style definitions

## Common Gotchas

1. **SafeAsync**: Always use `SafeAsync.run` or `.when()` to handle loading/error states in UI
2. **File Paths**: Use `path_provider` for app directory (don't hardcode paths); always organize under `/files/`
3. **Permissions**: Request at runtime; check before any file operation
4. **Widget Refresh**: Use `ref.watch(provider)` (riverpod); never call notifiers directly from widgets
5. **FFmpeg Calls**: Always check `ReturnCode` from FFmpeg operations for success/failure

## ANTI-HALLUCINATION & VERSION-SAFETY INSTRUCTION:
When generating code or architecture for this project, follow these rules strictly:

1. Do NOT use outdated or deprecated APIs.
	1. Always assume latest stable Flutter SDK and latest plugin versions.
	2. Do NOT use old patterns unless explicitly requested.
2. Never generate undefined variables, methods, or classes.
	1. Every variable, method, and class must be declared or clearly referenced.
	2. If something is assumed, clearly state the assumption.
3. No fake or guessed APIs.
	1. Do not invent plugin methods or FFmpeg commands.
	2. If an API is uncertain, explain it in text before using it.
4. Use explicit imports and correct file references.
	1. Do not reference files, providers, or services that were not created earlier.
	2. If a dependency is missing, mention it clearly.
5. Version clarity is mandatory.
	1. Mention Flutter version compatibility if relevant.
	2. Mention plugin names exactly as used in pub.dev.
6. Step-wise generation only.
	1. Generate one module at a time.
	2. Do not jump ahead to future modules.
7. Fail safely.
	1. Wrap async and heavy logic in try/catch.
	2. Provide graceful error handling.
8. No magic values.
	1. Avoid hard-coded sizes, durations, or paths.
	2. Use constants or configuration objects.
9. Cross-check before final output.
	1. Re-verify variables, references, and imports mentally before responding.
	2. Output must compile logically.
10. If something is ambiguous:
	1. Ask a clarification OR
	2. Provide a safe placeholder with TODO comment.

## RESPONSIVE UI RULES

1. No fixed heights unless unavoidable
2. Always use LayoutBuilder for size awareness
3. Use Expanded/Flexible correctly
4. Use scroll only where required
5. Timeline items must be virtualized
6. Adaptive layouts:
  Mobile: Preview → Timeline → Tools
  Tablet: Split preview + timeline
  Desktop: Multi-panel layout
