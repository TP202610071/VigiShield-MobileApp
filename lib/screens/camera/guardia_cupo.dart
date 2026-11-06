import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/services/cupo_servidor.dart';

/// Envuelve el video de una cámara. Si el servidor está lleno (la cámara está
/// en cola) o el administrador la deshabilitó, muestra el aviso en lugar del
/// video y avisa con [alCambiar] para que la pantalla detenga o reabra el
/// reproductor. Consulta cada 10 s; si no se puede saber, muestra el video.
class GuardiaCupo extends StatefulWidget {
  const GuardiaCupo({super.key, required this.cam, required this.child, this.alCambiar});

  final CameraConfigModel cam;
  final Widget child;

  /// true: el video quedó tapado (cola o bloqueo). false: se puede ver otra vez.
  final ValueChanged<bool>? alCambiar;

  @override
  State<GuardiaCupo> createState() => _GuardiaCupoState();
}

class _GuardiaCupoState extends State<GuardiaCupo> {
  EstadoCupo? _estado;
  Timer? _timer;

  bool get _tapa => _estado?.esCola == true || _estado?.esBloqueada == true;

  @override
  void initState() {
    super.initState();
    _consultar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _consultar());
  }

  @override
  void didUpdateWidget(GuardiaCupo old) {
    super.didUpdateWidget(old);
    if (old.cam.id != widget.cam.id) {
      _estado = null;
      _consultar();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    final id = widget.cam.id;
    final e = await CupoServidor.consultar(context.read<ApiClient>(), widget.cam);
    if (!mounted || widget.cam.id != id) return;
    final antes = _tapa;
    setState(() => _estado = e);
    if (antes != _tapa) widget.alCambiar?.call(_tapa);
  }

  @override
  Widget build(BuildContext context) {
    final e = _estado;
    if (e == null || !_tapa) return widget.child;
    final l10n = context.l10n;
    final bloqueada = e.esBloqueada;
    final apaisado = MediaQuery.orientationOf(context) == Orientation.landscape;
    return ColoredBox(
      color: AppColorsOscuros.background,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: apaisado ? 12 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  bloqueada ? Icons.block_rounded : Icons.hourglass_top_rounded,
                  color: bloqueada ? AppColorsOscuros.alertRed : AppColorsOscuros.warningAmber,
                  size: apaisado ? 30 : 44,
                ),
                SizedBox(height: apaisado ? 8 : 14),
                Text(
                  bloqueada ? l10n.cupoBloqueadaTitulo : l10n.cupoColaTitulo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColorsOscuros.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bloqueada ? l10n.cupoBloqueadaCuerpo : l10n.cupoColaCuerpo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColorsOscuros.textSecondary, fontSize: 12.5, height: 1.4),
                ),
                if (!bloqueada) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColorsOscuros.warningAmber.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.cupoPosicion(e.posicion, e.enCola),
                      style: GoogleFonts.inter(
                        color: AppColorsOscuros.warningAmber,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.cupoSeActualiza,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColorsOscuros.textSecondary, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension CupoStrings on AppStrings {
  String get cupoColaTitulo => en ? 'Server under high demand' : 'Servidor con alta demanda';
  String get cupoColaCuerpo => en
      ? 'VigiShield is in its beta phase, and the server can analyze only a limited number of cameras at the same time. Your camera is in the queue and will connect on its own when a spot opens up. Please try again later.'
      : 'VigiShield se encuentra en fase beta y el servidor analiza un número limitado de cámaras a la vez. Tu cámara está en la cola y se conectará sola cuando se libere un lugar. Intenta de nuevo más tarde.';
  String cupoPosicion(int posicion, int total) =>
      en ? 'Position in queue: $posicion of $total' : 'Posición en la cola: $posicion de $total';
  String get cupoSeActualiza => en ? 'Updates every 10 seconds.' : 'Se actualiza cada 10 segundos.';
  String get cupoBloqueadaTitulo =>
      en ? 'Camera disabled by the administrator' : 'Cámara deshabilitada por el administrador';
  String get cupoBloqueadaCuerpo => en
      ? 'This camera is not being processed or streamed. If you think this is a mistake, please contact the VigiShield team.'
      : 'Esta cámara no se procesa ni se transmite. Si crees que se trata de un error, comunícate con el equipo de VigiShield.';
}
