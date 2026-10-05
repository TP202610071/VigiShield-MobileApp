import 'package:flutter/material.dart';
import '../core/orientation/orientacion_app.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/ui_provider.dart';
import '../widgets/vs_bottom_nav.dart';

/// Le dice a [OrientacionApp] si la pestaña Cámara es lo que se ve (para
/// ponerla en horizontal; todo lo demás va en vertical, transmita o no). Las
/// pantallas no fijan la orientación por su cuenta, o se pelean entre ellas.
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of crea una dependencia: esto se vuelve a llamar cuando se
    // abre o se cierra una pantalla encima de las pestañas.
    _applyOrientation();
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fires whenever the active branch changes (taps and programmatic nav).
    _applyOrientation();
  }

  /// Horizontal solo si la pestaña Cámara es lo que se VE. Antes bastaba con
  /// que fuera la pestaña de debajo: con Mis cámaras o el editor de zonas
  /// abiertos encima, cualquier redibujado giraba la app a horizontal (por
  /// ejemplo al guardar zonas), y la grabación de pantalla se cortaba.
  void _applyOrientation() {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    OrientacionApp.instance.setPestanaCamara(
        visible && widget.navigationShell.currentIndex == _cameraTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Hide the app's bottom nav when the camera is fullscreen so the live view
    // takes the entire screen (the system bars are hidden by the camera screen).
    final fullscreen = context.watch<UiProvider>().cameraFullscreen;
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: fullscreen
          ? null
          : VsBottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) {
                // Gira en el mismo toque, sin esperar al redibujado.
                OrientacionApp.instance.setPestanaCamara(index == _cameraTabIndex);
                widget.navigationShell.goBranch(
                  index,
                  initialLocation: index == widget.navigationShell.currentIndex,
                );
              },
            ),
    );
  }
}
