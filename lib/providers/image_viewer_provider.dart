import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImageViewerState {
  final int currentIndex;
  final bool isFullscreen;
  final bool showControls;
  final bool isSlideshow;
  final double brightness;
  final double contrast;
  final double saturation;
  final int rotation; // 0, 90, 180, 270

  const ImageViewerState({
    this.currentIndex = 0,
    this.isFullscreen = false,
    this.showControls = true,
    this.isSlideshow = false,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.rotation = 0,
  });

  ImageViewerState copyWith({
    int? currentIndex,
    bool? isFullscreen,
    bool? showControls,
    bool? isSlideshow,
    double? brightness,
    double? contrast,
    double? saturation,
    int? rotation,
  }) {
    return ImageViewerState(
      currentIndex: currentIndex ?? this.currentIndex,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      showControls: showControls ?? this.showControls,
      isSlideshow: isSlideshow ?? this.isSlideshow,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      rotation: rotation ?? this.rotation,
    );
  }
}

class ImageViewerNotifier extends Notifier<ImageViewerState> {
  @override
  ImageViewerState build() {
    return ImageViewerState();
  }

  void setIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void nextImage(int totalImages) {
    if (state.currentIndex < totalImages - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void previousImage() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void toggleFullscreen() {
    state = state.copyWith(
      isFullscreen: !state.isFullscreen,
      showControls: state.isFullscreen, // Show controls when exiting fullscreen
    );
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void hideControls() {
    state = state.copyWith(showControls: false);
  }

  void showControls() {
    state = state.copyWith(showControls: true);
  }

  void toggleSlideshow() {
    state = state.copyWith(isSlideshow: !state.isSlideshow);
  }

  void setBrightness(double value) {
    state = state.copyWith(brightness: value);
  }

  void setContrast(double value) {
    state = state.copyWith(contrast: value);
  }

  void setSaturation(double value) {
    state = state.copyWith(saturation: value);
  }

  void rotate() {
    final newRotation = (state.rotation + 90) % 360;
    state = state.copyWith(rotation: newRotation);
  }

  void resetAdjustments() {
    state = state.copyWith(
      brightness: 0,
      contrast: 0,
      saturation: 0,
      rotation: 0,
    );
  }
}

final imageViewerProvider =
    NotifierProvider.autoDispose<ImageViewerNotifier, ImageViewerState>(
      () => ImageViewerNotifier(),
    );
