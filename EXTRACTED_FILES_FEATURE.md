# Screenshots, Audio Extract, and Frames Feature

## Overview
This document describes the implementation of screenshot capture, audio extraction, and frame extraction functionality for the Slideup Media Player app. All extracted files are saved to the app's application documents directory under the `/files` folder with organized subdirectories.

## Features Implemented

### 1. Screenshots
- **Location**: `AppDocumentsDirectory/files/screenshots/`
- **Formats**: PNG, JPG, BMP, WebP
- **Functionality**: Capture current video frame at any position
- **Usage**: Long-press on video or tap the "Capture Screenshot" button in the more options menu

### 2. Audio Extraction
- **Location**: `AppDocumentsDirectory/files/audio/`
- **Formats**: MP3, AAC, WAV, FLAC
- **Functionality**: Extract audio track from video with optional bitrate control
- **Usage**: Tap "Extract Audio" button and select desired format

### 3. Frame Extraction
- **Location**: `AppDocumentsDirectory/files/frames/`
- **Organization**: Each extraction session creates a timestamped subdirectory
- **Formats**: JPG, PNG, BMP, WebP
- **Functionality**: Extract multiple frames at specified FPS rate
- **Usage**: Tap "Extract Frames" button to extract frames from entire video

## Directory Structure
```
AppDocumentsDirectory/
└── files/
    ├── screenshots/
    │   ├── screenshot_1702778400000.png
    │   ├── screenshot_1702778500000.png
    │   └── ...
    ├── audio/
    │   ├── video_name_audio_1702778400000.mp3
    │   ├── video_name_audio_1702778500000.aac
    │   └── ...
    └── frames/
        ├── frames_1702778400000/
        │   ├── frame_0001.jpg
        │   ├── frame_0002.jpg
        │   └── ...
        └── frames_1702778500000/
            └── ...
```

## Code Changes

### 1. `lib/services/video_service.dart`
**Changes Made:**
- Added helper methods for app directory management:
  - `_getAppFilesDirectory()` - Creates and returns the main files directory
  - `_getScreenshotsDirectory()` - Returns the screenshots subdirectory
  - `_getAudioDirectory()` - Returns the audio subdirectory
  - `_getFramesDirectory()` - Returns the frames subdirectory

- Updated `captureScreenshot()` to save to `files/screenshots/` instead of temporary directory
- Updated `extractAudio()` to save to `files/audio/` instead of application documents root
- Updated `extractFrames()` to save to `files/frames/` instead of temporary directory

### 2. `lib/screens/video_player_screen.dart`
**No Changes Required** - Already contains UI methods:
- `_captureScreenshot()` - Captures screenshot and saves to gallery
- `_extractAudio()` - Shows format selection dialog and extracts audio
- `_extractFrames()` - Extracts frames with default 1 FPS

The video player screen already has UI buttons for these actions in the more options menu.

### 3. `lib/screens/extracted_files_screen.dart` (NEW)
**Purpose**: Browse, manage, and view all extracted files

**Features:**
- **Category Filtering**: View all files or filter by category (Screenshots, Audio, Frames)
- **File Information**: Display file name, size, and category
- **File Operations**:
  - Open file with default application
  - Delete individual files
  - Delete all files with confirmation
- **Smart Sorting**: Files sorted by modification date (newest first)
- **File Type Icons**: Different icons for images, audio, and video files
- **File Size Formatting**: Displays size in B, KB, or MB
- **Empty State**: Shows helpful message when no files found

### 4. `lib/screens/main_screen.dart`
**Changes Made:**
- Added import for `ExtractedFilesScreen`
- Added new drawer menu item "Extracted Files" that navigates to the new screen

## Usage Guide

### Capturing Screenshots
1. Open a video in the video player
2. Tap the menu button (three dots)
3. Select "Capture Screenshot"
4. Screenshot is saved to `files/screenshots/` and gallery

### Extracting Audio
1. Open a video in the video player
2. Tap the menu button (three dots)
3. Select "Extract Audio"
4. Choose audio format (MP3, AAC, WAV, FLAC)
5. Audio is extracted and saved to `files/audio/`

### Extracting Frames
1. Open a video in the video player
2. Tap the menu button (three dots)
3. Select "Extract Frames"
4. Frames are extracted at 1 FPS and saved to `files/frames/`

### Managing Extracted Files
1. From the main screen, open the drawer menu
2. Tap "Extracted Files"
3. Browse files by category or view all
4. Use filters to switch between Screenshots, Audio, and Frames
5. Tap a file to view details
6. Long-press or use the menu to open or delete files
7. Use the menu button to delete all files at once

## File Access Permissions
- All files are saved in the app's sandboxed documents directory
- No special storage permissions required beyond standard app permissions
- Files are automatically organized in subdirectories
- Users can access files through the Extracted Files screen

## Technical Details

### FFmpeg Operations
- **Screenshots**: Uses `-ss` to seek to timestamp and `-vframes 1` to capture single frame
- **Audio**: Removes video stream with `-vn` and converts to desired audio codec
- **Frames**: Uses `-vf fps=X` to extract frames at specified rate

### Storage
- Uses `getApplicationDocumentsDirectory()` for reliable cross-platform storage
- Creates subdirectories automatically on first use
- Organized by file type for easy browsing and management

## Dependencies Required
- `path_provider` - For app directory access
- `ffmpeg_kit_flutter_new` - For audio/video processing
- `saver_gallery` - For saving screenshots to gallery
- `open_filex` - For opening extracted files

## Notes
- All operations use FFmpeg Kit for reliable media processing
- Directory structure is created automatically
- File organization makes it easy to locate specific file types
- Gallery saves include automatic organization in device gallery
- Frame extraction creates timestamp-based subdirectories to avoid file conflicts
