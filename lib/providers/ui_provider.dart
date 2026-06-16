import 'package:flutter/foundation.dart';

/// Cross-screen UI state. Currently tracks whether the camera tab is in
/// fullscreen (immersive) mode so [MainShell] can hide its bottom navigation
/// bar — the camera screen lives inside the shell and can't remove the nav itself.
class UiProvider extends ChangeNotifier {
  bool _cameraFullscreen = false;
  bool get cameraFullscreen => _cameraFullscreen;

  void setCameraFullscreen(bool value) {
    if (_cameraFullscreen == value) return;
    _cameraFullscreen = value;
    notifyListeners();
  }
}
