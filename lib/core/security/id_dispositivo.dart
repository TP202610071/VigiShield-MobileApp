import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identificador del teléfono que la app envía en la cabecera X-Device-Id.
///
/// Sirve para que el administrador pueda bloquear un teléfono que crea varias
/// cuentas para sobrecargar el servidor de cámaras. En Android es ANDROID_ID
/// (sobrevive a reinstalar la app); en iPhone, un valor aleatorio guardado en
/// el llavero, que también se conserva al reinstalar.
class IdDispositivo {
  IdDispositivo._();

  static const _canal = MethodChannel('vigishield/dispositivo');
  static const _llave = 'vs_id_dispositivo';
  static const _almacen = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static Future<String?>? _id;

  static String get plataforma => Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'otro';

  static Future<String?> obtener() => _id ??= _cargar();

  static Future<String?> _cargar() async {
    try {
      if (Platform.isAndroid) {
        final id = await _canal.invokeMethod<String>('id');
        if (id != null && id.length >= 8) return 'a-$id';
      }
      final guardado = await _almacen.read(key: _llave);
      if (guardado != null && guardado.length >= 8) return guardado;
      final r = Random.secure();
      final nuevo = '${Platform.isIOS ? 'i' : 'x'}-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      await _almacen.write(key: _llave, value: nuevo);
      return nuevo;
    } catch (_) {
      return null;
    }
  }
}
