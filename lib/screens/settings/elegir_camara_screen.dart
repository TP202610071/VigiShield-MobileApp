import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/mobile_camera_publisher.dart';
import '../../widgets/animaciones.dart';
import '../camera/device_camera_screen.dart';

/// «Agregar cámara»: primero se elige qué cámara. Antes eran dos opciones en
/// una hoja inferior desde «Mis cámaras», y el inicio llevaba directo a la de
/// cámara IP sin mostrar la otra.
class ElegirCamaraScreen extends StatelessWidget {
  const ElegirCamaraScreen({super.key});

  static const ruta = '/settings/cameras/nueva';

  Future<void> _usarEsteCelular(BuildContext context) async {
    final transmitiendo = await Navigator.of(context).push(MaterialPageRoute<bool>(
      builder: (_) => const DeviceCameraScreen()));
    if (transmitiendo != true || !context.mounted) return;
    // Recién empezó a transmitir: lo siguiente es dibujar las zonas de interés.
    final id = context.read<MobileCameraPublisher>().cameraId;
    if (id != null) context.pushReplacement('/settings/cameras/$id/zones?intro=1');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(s.elegirCamaraTitulo)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          Text(s.elegirCamaraPregunta,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(s.elegirCamaraAyuda,
              style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Aparecer(
            child: _Opcion(
              key: const Key('opcion-camara-ip'),
              icono: Icons.videocam_outlined,
              titulo: s.elegirCamaraIp,
              texto: s.elegirCamaraIpTexto,
              detalle: s.elegirCamaraIpDetalle,
              onTap: () => context.push('/settings/cameras/add'),
            ),
          ),
          const SizedBox(height: 14),
          Aparecer(
            orden: 1,
            child: _Opcion(
              key: const Key('opcion-este-celular'),
              icono: Icons.smartphone_outlined,
              titulo: s.elegirCamaraCelular,
              texto: s.elegirCamaraCelularTexto,
              detalle: s.elegirCamaraCelularDetalle,
              onTap: () => _usarEsteCelular(context),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String detalle;
  final VoidCallback onTap;

  const _Opcion({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, color: AppColors.accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(texto, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(detalle, style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: AppColors.textMuted)),
              ]),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

extension ElegirCamaraStrings on AppStrings {
  String get elegirCamaraTitulo => en ? 'Add camera' : 'Agregar cámara';
  String get elegirCamaraPregunta => en ? 'Which camera do you want to add?' : '¿Qué cámara quieres agregar?';
  String get elegirCamaraAyuda => en
      ? 'You can add more later and mix both kinds.'
      : 'Después puedes agregar más y combinar los dos tipos.';
  String get elegirCamaraIp => en ? 'IP camera' : 'Cámara IP';
  String get elegirCamaraIpTexto => en
      ? 'A security camera at home that streams video over the network (RTSP).'
      : 'Una cámara de seguridad de tu casa que transmite video por la red (RTSP).';
  String get elegirCamaraIpDetalle => en
      ? 'Hikvision, Dahua, Reolink, TP-Link Tapo and most brands. You will need its IP, user and password.'
      : 'Hikvision, Dahua, Reolink, TP-Link Tapo y la mayoría de marcas. Necesitarás su IP, usuario y contraseña.';
  String get elegirCamaraCelular => en ? 'This phone as a camera' : 'Este celular como cámara';
  String get elegirCamaraCelularTexto => en
      ? 'Use this phone, or one you no longer use, pointing at your entrance.'
      : 'Usa este teléfono, o uno que ya no uses, apuntando a la entrada de tu casa.';
  String get elegirCamaraCelularDetalle => en
      ? 'It streams while VigiShield is open on that phone. No extra equipment needed.'
      : 'Transmite mientras VigiShield esté abierta en ese teléfono. No necesitas otro equipo.';
}
