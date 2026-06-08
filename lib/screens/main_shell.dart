import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../widgets/vs_bottom_nav.dart';

/// Owns screen orientation: the camera tab is locked landscape, every other tab
/// is locked portrait — regardless of the phone's physical rotation or the OS
/// auto-rotate setting. This is the single source of truth (the individual
/// screens must NOT set orientation themselves, or they fight each other).
class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Router branch order is [dashboard, camera, history, settings].
  static const _cameraTabIndex = 1;

  @override
  void initState() {
    super.initState();
    _applyOrientation(widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fires whenever the active branch changes (taps and programmatic nav).
    _applyOrientation(widget.navigationShell.currentIndex);
  }

  static void _applyOrientation(int index) {
    if (index == _cameraTabIndex) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: VsBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) {
          _applyOrientation(index); // snap immediately on tap
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
