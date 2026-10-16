import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/dev_settings_provider.dart';
import 'tutorial/tutorial_claves.dart';
import 'video_ejemplo.dart';
import '../screens/settings/elegir_camara_screen.dart';

/// Tarjeta del inicio: primero, que agregue su cámara; el video de ejemplo,
/// después.
///
/// En las pruebas con usuarios, muchos tocaban «Ver video de ejemplo» apenas
/// entraban y ya no agregaban una cámara. Ahora, mientras el hogar no tenga
/// cámaras propias, el inicio muestra ese aviso con el botón para agregar una
/// (aunque haya un video de ejemplo en curso: ese se ve en la pestaña Cámara);
/// la tarjeta del video de ejemplo aparece cuando ya hay al menos una.
class TarjetaInicioCamaras extends StatefulWidget {
  const TarjetaInicioCamaras({super.key});

  @override
  State<TarjetaInicioCamaras> createState() => _TarjetaInicioCamarasState();
}

class _TarjetaInicioCamarasState extends State<TarjetaInicioCamaras> {
  // El aviso de "sin cámaras" solo sale cuando de verdad se consultó la lista:
  // antes de eso (o si falló por la red) no se sabe, y no debe parpadear.
  bool _consultado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = context.read<CameraProvider>();
      await p.fetchCameras();
      if (mounted && p.error == null) setState(() => _consultado = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final camaras = context.watch<CameraProvider>();
    if (camaras.misCamaras.isNotEmpty) {
      return KeyedSubtree(key: TutorialClaves.tarjetaCamaras, child: const TarjetaVideoEjemplo());
    }
    if (!_consultado) return const SizedBox.shrink();

    final s = context.l10n;
    final principal = context.watch<DevSettingsProvider>().isPrimaryEffective(context.read<AuthProvider>().user);
    return Container(
      key: TutorialClaves.tarjetaCamaras,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withAlpha(153)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.videocam_off_outlined, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.sinCamarasTitulo,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(principal ? s.sinCamarasTexto : s.sinCamarasTextoSecundario,
            style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
        if (principal) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: TutorialClaves.agregarCamara,
              onPressed: () => context.push(ElegirCamaraScreen.ruta),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(s.sinCamarasBoton,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

extension InicioCamarasStrings on AppStrings {
  String get sinCamarasTitulo => en ? 'You have no cameras yet' : 'Aún no tienes cámaras';
  String get sinCamarasTexto => en
      ? 'Start here: add an IP camera from your home or use this phone as a camera. VigiShield '
          'starts watching as soon as it receives the video.'
      : 'Empieza aquí: agrega una cámara IP de tu casa o usa este celular como cámara. VigiShield '
          'empieza a vigilar apenas recibe el video.';
  String get sinCamarasTextoSecundario => en
      ? 'The main resident has not added a camera yet. When they do, you will see it here.'
      : 'El residente principal aún no agregó una cámara. Cuando lo haga, la verás aquí.';
  String get sinCamarasBoton => en ? 'Add camera' : 'Agregar cámara';
}
