import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pide el permiso de cámara EN CONTEXTO: explicando antes para qué es, como
/// recomiendan Apple y Google. Antes no se pedía hasta pulsar «Iniciar
/// transmisión» y, si se había denegado una vez, la transmisión fallaba sin
/// explicar por qué.
///
/// Devuelve true si se puede usar la cámara.
Future<bool> asegurarPermisoCamara(BuildContext context) async {
  PermissionStatus estado;
  try {
    estado = await Permission.camera.status;
  } catch (_) {
    return true; // sin plugin (pruebas): lo resuelve la propia cámara
  }
  if (estado.isGranted || estado.isLimited) return true;
  if (!context.mounted) return false;
  if (estado.isPermanentlyDenied || estado.isRestricted) {
    await _abrirAjustes(context);
    return false;
  }
  final seguir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.videocam_outlined, size: 36),
      title: const Text('Permiso de cámara'),
      content: const Text(
          'Para usar este teléfono como cámara de vigilancia, VigiShield necesita acceder a la cámara. '
          'El video se envía a tu cuenta sin audio y solo mientras transmites.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
      ],
    ),
  );
  if (seguir != true) return false;
  try {
    estado = await Permission.camera.request();
  } catch (_) {
    return true;
  }
  if (estado.isGranted || estado.isLimited) return true;
  if (estado.isPermanentlyDenied && context.mounted) await _abrirAjustes(context);
  return false;
}

Future<void> _abrirAjustes(BuildContext context) async {
  final abrir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Activa el permiso de cámara'),
      content: const Text(
          'El permiso de cámara está desactivado para VigiShield. Actívalo en los Ajustes del teléfono '
          '(Permisos > Cámara) y vuelve a la aplicación.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir ajustes')),
      ],
    ),
  );
  if (abrir == true) await openAppSettings();
}
