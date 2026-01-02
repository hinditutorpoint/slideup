# TTS Initialization Fix

## Problem
The application was throwing the error: `[TtsService] Initialization error: Exception: Please initialize sherpa-onnx first`

## Root Cause
The Sherpa ONNX library requires explicit initialization via `sherpa.initBindings()` before any of its classes (like `OfflineTts`) can be used. This initialization was missing in the code.

## Solution
Added proper Sherpa initialization to the TtsService with comprehensive error handling and checks throughout the TTS system.

## Changes Made

### 1. TtsService.dart
- Added global flag `_sherpaInitialized` to track initialization state
- Added `_ensureSherpaInitialized()` method to call `sherpa.initBindings()`
- Updated `_initializeEngine()` to call Sherpa initialization first
- Updated `_getEngine()` to ensure Sherpa is initialized
- Added `isSherpaInitialized` property
- Updated `isInitialized` to include Sherpa initialization check

### 2. TtsController.dart
- Updated `initializeWithActiveModel()` to check Sherpa initialization
- Updated `speak()` method to verify Sherpa is initialized before proceeding
- Updated `generateOnly()` method to check Sherpa initialization
- Updated `initializeWithModel()` method with Sherpa initialization comments
- Updated `preGeneratePages()` method to check Sherpa initialization
- Updated `isPageCached()` method to check Sherpa initialization
- Added `isSherpaInitialized` property to TtsController

## Key Features of the Fix

1. **Single Initialization**: Sherpa bindings are initialized exactly once using a global flag
2. **Comprehensive Checks**: All TTS operations now check for proper Sherpa initialization
3. **Error Handling**: Clear error messages are provided when initialization fails
4. **Graceful Degradation**: The system gracefully handles missing models or initialization failures
5. **Debug Logging**: Added debug logging for initialization steps to help with troubleshooting

## How It Works

1. When any TTS operation is called, the system first checks if Sherpa bindings are initialized
2. If not initialized, it calls `sherpa.initBindings()` to initialize the library
3. If initialization fails, appropriate error messages are logged and the operation fails gracefully
4. Once initialized, all subsequent TTS operations work normally

## Testing

The fix ensures that:
- Sherpa bindings are initialized exactly once
- All TTS operations check for proper initialization
- Clear error messages are provided when initialization fails
- The system gracefully handles missing models

## Files Modified
- `lib/features/speaker_player/services/tts_service.dart`
- `lib/features/speaker_player/tts_controller.dart`

This fix resolves the "Please initialize sherpa-onnx first" error and ensures the TTS functionality works properly when models are available.