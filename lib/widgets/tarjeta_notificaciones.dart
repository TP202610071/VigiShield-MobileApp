import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../data/services/notificaciones_push.dart';
import 'vs_cargando.dart';

/// Ajustes → Notificaciones: si este teléfono recibe las alertas y un botón
/// para enviarse una de prueba.
class TarjetaNotificaciones extends StatefulWidget {
  const TarjetaNotificaciones({super.key});

  @override
  State<TarjetaNotificaciones> createState() => _TarjetaNotificacionesState();
}

class _TarjetaNotificacionesState extends State<TarjetaNotificaciones> {
  bool _ocupado = false;

  Future<void> _accion(NotificacionesPush push) async {
    final s = context.l10n;
    final avisos = ScaffoldMessenger.maybeOf(context);
    setState(() => _ocupado = true);
    String mensaje;
    try {
      switch (push.estado) {
        case EstadoPush.activas:
          final r = await push.enviarPrueba();
          mensaje = !r.configurado
              ? s.pushServidorSinConfigurar
              : r.enviados > 0
                  ? s.pushPruebaEnviada
                  : s.pushPruebaFallo;
        case EstadoPush.sinPermiso:
          await openAppSettings();
          mensaje = '';
        default:
          await push.activar(forzar: true);
          mensaje = push.estado == EstadoPush.activas ? s.pushActivadas : '';
      }
    } on ApiException catch (e) {
      mensaje = e.message;
    } catch (_) {
      mensaje = s.pushPruebaFallo;
    }
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (mensaje.isNotEmpty) avisos?.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final push = context.watch<NotificacionesPush?>();
    if (push == null || !NotificacionesPush.soportado) return const SizedBox.shrink();
    final s = context.l10n;
    final (detalle, boton) = switch (push.estado) {
      EstadoPush.activas => (s.pushActivasDetalle, s.pushEnviarPrueba),
      EstadoPush.sinPermiso => (s.pushSinPermisoDetalle, s.pushAbrirAjustes),
      EstadoPush.noDisponible => (s.pushNoDisponibleDetalle, s.pushReintentar),
      EstadoPush.desconocido => (s.pushDesconocidoDetalle, s.pushActivar),
    };
    final activas = push.estado == EstadoPush.activas;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(activas ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            color: activas ? AppColors.safeGreen : AppColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.pushTitulo, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(detalle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
          ]),
        ),
        _ocupado
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(width: 18, height: 18, child: VsCargando(color: AppColors.accent)),
              )
            : TextButton(
                onPressed: () => _accion(push),
                child: Text(boton, style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
              ),
      ]),
    );
  }
}

extension NotificacionesStrings on AppStrings {
  String get pushTitulo => en ? 'Notifications' : 'Notificaciones';
  String get pushActivasDetalle => en ? 'This phone receives the alerts.' : 'Este teléfono recibe las alertas.';
  String get pushSinPermisoDetalle => en
      ? 'Not allowed. Turn them on in the phone settings.'
      : 'Sin permiso. Actívalas en los ajustes del teléfono.';
  String get pushNoDisponibleDetalle =>
      en ? 'This phone cannot receive them yet.' : 'Este teléfono aún no puede recibirlas.';
  String get pushDesconocidoDetalle =>
      en ? 'Get the alerts even with the app closed.' : 'Recibe las alertas aunque la app esté cerrada.';
  String get pushEnviarPrueba => en ? 'Test' : 'Probar';
  String get pushAbrirAjustes => en ? 'Settings' : 'Ajustes';
  String get pushReintentar => en ? 'Retry' : 'Reintentar';
  String get pushActivar => en ? 'Turn on' : 'Activar';
  String get pushActivadas => en ? 'Notifications turned on.' : 'Notificaciones activadas.';
  String get pushPruebaEnviada =>
      en ? 'Sent. It should arrive in a few seconds.' : 'Enviada. Debería llegar en unos segundos.';
  String get pushPruebaFallo => en ? 'Could not send the test.' : 'No se pudo enviar la prueba.';
  String get pushServidorSinConfigurar => en
      ? 'The server does not have notifications configured yet.'
      : 'El servidor aún no tiene configuradas las notificaciones.';
}
