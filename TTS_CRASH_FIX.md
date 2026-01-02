# TTS Crash Fix

## Problem
The application was crashing with the error:
```
I/Choreographer(18564): Skipped 2 frames! The application may be doing too much work on its main thread.
I/zygote64(18564): Thread[3,tid=18659,WaitingInMainSignalCatcherLoop,Thread*=0x7abe8c5400,peer=0x1d9c5e38,"Signal Catcher"]: reacting to signal 3
```

## Root Cause
The Sherpa library initialization (`sherpa.initBindings()`) was being called synchronously on the main thread, causing the UI to freeze and eventually crash due to the heavy initialization work blocking the main thread.

## Solution
Moved Sherpa initialization to a background isolate using `compute()` and added proper timeout handling and user feedback.

## Changes Made

### 1. TtsService.dart
- Added `_initSherpaBindings()` helper method for isolate initialization
- Updated `_ensureSherpaInitialized()` to use `compute()` for background processing
- Added loading state during initialization
- Added 30-second timeout to prevent hanging
- Added proper error handling with state updates

### 2. TtsController.dart
- Added `_waitForSherpaInitialization()` method to wait for initialization completion
- Updated all TTS methods to wait for Sherpa initialization instead of failing immediately
- Added user-friendly error messages with retry options
- Updated `initializeWithActiveModel()`, `speak()`, `generateOnly()`, `preGeneratePages()`, and `isPageCached()` methods

## Key Features of the Fix

1. **Background Initialization**: Sherpa bindings are initialized in a background isolate to prevent blocking the main thread
2. **Timeout Handling**: 30-second timeout prevents hanging if initialization takes too long
3. **User Feedback**: Loading states and error messages provide feedback during initialization
4. **Graceful Waiting**: Methods wait for initialization completion instead of failing immediately
5. **Error Recovery**: Users can retry initialization if it fails

## How It Works

1. When TTS operations are called, the system checks if Sherpa is initialized
2. If not initialized, it starts background initialization using `compute()`
3. The UI shows loading state while waiting for initialization
4. Once initialized, TTS operations proceed normally
5. If initialization fails or times out, users get clear error messages with retry options

## Benefits

- **No More Crashes**: Sherpa initialization no longer blocks the main thread
- **Better UX**: Users see loading states instead of frozen UI
- **Error Recovery**: Users can retry if initialization fails
- **Timeout Protection**: Prevents indefinite hanging
- **Background Processing**: Heavy initialization work happens off the main thread

## Files Modified
- `lib/features/speaker_player/services/tts_service.dart`
- `lib/features/speaker_player/tts_controller.dart`

This fix resolves the main thread blocking issue and prevents the application from crashing during TTS initialization.