import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/permiso_camara.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/services/estado_transmision.dart';
import '../../data/services/mobile_camera_publisher.dart';

/// Empieza a transmitir [cam] desde este celular, con la lente que usó la
/// última vez. Devuelve el error para mostrar, o null si quedó transmitiendo.
///
/// Se usa desde la pestaña Cámara y desde «Mis cámaras», para no tener que ir
/// a la pantalla de la cámara del dispositivo solo para pulsar un botón.
Future<String?> transmitirDesdeEsteCelular(BuildContext context, CameraConfigModel cam) async {
  final l10n = context.l10n;
  final pub = context.read<MobileCameraPublisher?>();
  if (pub == null) return l10n.phoneCamStartFailed;
  if (transmiteEsteTelefono(cam, pub)) return null;
  if (!await asegurarPermisoCamara(context)) return l10n.phoneCamNeedsPermission;
  // Si este celular transmitía otra cámara, o la parada al salir de la app
  // sigue a medias, start() no haría nada: primero se termina de parar.
  await pub.stop();
  await pub.start(cam.id, front: pub.front);
  if (pub.isPublishing && pub.cameraId == cam.id) return null;
  return pub.error ?? l10n.phoneCamStartFailed;
}

/// Lo que se ve en la pestaña Cámara cuando la cámara es un celular y nadie
/// la está transmitiendo.
///
/// Antes se veía «Conectando…» para siempre: quien salía de la app para hacer
/// otra cosa volvía, veía la rueda girando y creía que el sistema no
/// funcionaba. Aquí se explica por qué no hay video y el botón para volver a
/// transmitir queda a la vista.
class AvisoSinTransmision extends StatelessWidget {
  const AvisoSinTransmision({
    super.key,
    required this.puedeTransmitir,
    required this.arrancando,
    this.error,
    this.onTransmitir,
  });

  /// Solo el residente principal puede transmitir (el servidor lo exige).
  final bool puedeTransmitir;

  /// Este celular ya está iniciando la transmisión.
  final bool arrancando;
  final String? error;
  final VoidCallback? onTransmitir;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final apaisado = MediaQuery.orientationOf(context) == Orientation.landscape;
    final alineado = apaisado ? TextAlign.start : TextAlign.center;
    final cruz = apaisado ? CrossAxisAlignment.start : CrossAxisAlignment.center;

    final explicacion = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cruz,
      children: [
        Icon(Icons.phonelink_off, color: AppColors.warningAmber, size: apaisado ? 30 : 44),
        SizedBox(height: apaisado ? 8 : 14),
        Text(
          l10n.phoneCamOffTitle,
          textAlign: alineado,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.phoneCamOffBody,
          textAlign: alineado,
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
        ),
      ],
    );

    final acciones = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (puedeTransmitir) ...[
          FilledButton.icon(
            key: const Key('transmitir-aqui'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: arrancando ? null : onTransmitir,
            icon: arrancando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                  )
                : const Icon(Icons.videocam, size: 20),
            label: Text(
              arrancando ? l10n.phoneCamStarting : l10n.phoneCamStartHere,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.phoneCamOtherPhone,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11.5),
          ),
        ] else
          Text(
            l10n.phoneCamAskPrimary,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.alertRed, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.phoneCamWaiting,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );

    // En horizontal (la pestaña Cámara) sobra ancho y falta alto: la
    // explicación a la izquierda y el botón a la derecha. El margen deja libre
    // la barra de arriba y los botones de abajo, que van encima del contenido.
    return Center(
      child: SingleChildScrollView(
        padding: apaisado
            ? const EdgeInsets.fromLTRB(40, 56, 40, 92)
            : const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: apaisado ? 860 : 440),
          child: apaisado
              ? Row(
                  children: [
                    Expanded(flex: 5, child: explicacion),
                    const SizedBox(width: 32),
                    Expanded(flex: 4, child: acciones),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [explicacion, const SizedBox(height: 20), acciones],
                ),
        ),
      ),
    );
  }
}
