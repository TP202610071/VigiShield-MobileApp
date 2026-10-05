import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/camera_provider.dart';
import '../providers/system_provider.dart';
import 'vs_button.dart';

/// Inicia un video de ejemplo y abre la pestaña Cámara para verlo.
///
/// Sirve para quien prueba la app y no logra que pase alguien frente a su
/// cámara: el motor analiza el video como una cámara más y sus eventos
/// quedan en el historial.
Future<void> abrirVideoDeEjemplo(BuildContext context, {bool otro = false}) async {
  final camaras = context.read<CameraProvider>();
  final ok = await camaras.iniciarEjemplo(otro: otro);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.sampleError)),
    );
    return;
  }
  context.go('/camera');
}

/// Tarjeta del inicio que ofrece el video de ejemplo, o lo muestra en curso.
class TarjetaVideoEjemplo extends StatelessWidget {
  const TarjetaVideoEjemplo({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camaras = context.watch<CameraProvider>();
    final enCurso = camaras.ejemplo;
    final pausado = !(context.watch<SystemProvider>().status?.isMonitoringActive ?? true);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enCurso != null ? AppColors.accent.withAlpha(153) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(31),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.movie_outlined, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enCurso != null ? l10n.sampleRunning : l10n.sampleCardTitle,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            enCurso != null
                ? (enCurso.sampleTitleFor(english: l10n.localeCode == 'en') ?? l10n.sampleVideo)
                : l10n.sampleCardBody,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          if (pausado) ...[
            const SizedBox(height: 8),
            Text(
              l10n.samplePaused,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.warningAmber, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          VsButton(
            key: const Key('ver-video-ejemplo'),
            label: enCurso != null ? l10n.sampleWatch : l10n.sampleCardAction,
            icon: Icons.play_arrow_rounded,
            isLoading: camaras.iniciandoEjemplo,
            onPressed: camaras.iniciandoEjemplo
                ? null
                : () => enCurso != null
                    ? context.go('/camera')
                    : abrirVideoDeEjemplo(context),
          ),
        ],
      ),
    );
  }
}
