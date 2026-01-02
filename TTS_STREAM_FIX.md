# TTS Stream Fix

## Problem
The TtsController was trying to access a non-existent `statusStream` property on the TtsService class, causing a compilation error:
```
The getter 'statusStream' isn't defined for the type 'TtsService'.
Try importing the library that defines 'statusStream', correcting the name to the name of an existing getter, or defining a getter or field named 'statusStream'.
```

## Root Cause
The TtsController's `_waitForSherpaInitialization()` method was trying to access `_ttsService.statusStream`, but the TtsService class only has a `stateStream` property, not `statusStream`.

## Solution
Fixed the stream name from `statusStream` to `stateStream` to match the actual property name in the TtsService class.

## Changes Made

### TtsController.dart
- Updated `_waitForSherpaInitialization()` method to use `_ttsService.stateStream` instead of `_ttsService.statusStream`
- Added explicit type annotation `StreamSubscription<TtsPlaybackState>` for clarity

## Understanding the Stream Types

1. **TtsService.stateStream**: Emits `TtsPlaybackState` events (idle, loading, generating, playing, paused, completed, error)
2. **TtsController.statusStream**: Returns `_audioPlayer.statusStream` which emits `TtsStatus` objects containing `TtsPlaybackState`
3. **TtsAudioPlayer.statusStream**: Emits `TtsStatus` objects

## How It Works

The `_waitForSherpaInitialization()` method:
1. Checks if Sherpa is already initialized
2. If not, listens to the TtsService's `stateStream` for initialization completion
3. Waits for either:
   - `TtsPlaybackState.idle` state with Sherpa initialized (success)
   - `TtsPlaybackState.error` state (failure)
   - 30-second timeout (failure)
4. Completes or errors the completer accordingly

## Files Modified
- `lib/features/speaker_player/tts_controller.dart`

This fix resolves the compilation error and ensures proper communication between the TtsController and TtsService during Sherpa initialization.