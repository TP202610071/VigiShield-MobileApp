import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/auth_storage.dart';

/// Tipo de biometría que ofrece el dispositivo, para nombrarla bien en la UI.
enum BiometricKind { faceId, touchId, fingerprint, generic, none }

/// Desbloqueo de la app con huella o rostro.
///
/// No sustituye al inicio de sesión: la sesión sigue siendo el token guardado.
/// Lo que añade es una puerta delante de ese token, que es justo lo que se
/// espera de una app de seguridad — quien coja el teléfono desbloqueado no
/// debería poder ver el video en vivo de la casa.
class BiometricLock {
  static const _claveActivado = 'vigishield_biometric_enabled';

  final LocalAuthentication _auth;
  final AuthStorage _storage;

  BiometricLock(this._storage, {LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// ¿El dispositivo tiene biometría utilizable ahora mismo?
  Future<bool> get disponible async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Qué biometría ofrece, para decir "Face ID" y no "biometría" a secas.
  Future<BiometricKind> get tipo async {
    try {
      final tipos = await _auth.getAvailableBiometrics();
      if (tipos.contains(BiometricType.face)) return BiometricKind.faceId;
      if (tipos.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
      if (tipos.isNotEmpty) return BiometricKind.generic;
      return BiometricKind.none;
    } on PlatformException {
      return BiometricKind.none;
    }
  }

  Future<bool> get activado async =>
      (await _storage.readValue(_claveActivado)) == '1';

  Future<void> activar(bool valor) =>
      _storage.writeValue(_claveActivado, valor ? '1' : '0');

  /// Pide la huella o el rostro. Devuelve true solo si el sistema la aceptó.
  ///
  /// Un fallo (cancelado, sin huellas registradas, bloqueado por intentos) NO
  /// se trata como éxito: la puerta se queda cerrada y se ofrece entrar con
  /// contraseña.
  Future<bool> verificar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        // false: el PIN o patron del movil vale como respaldo si la huella
        // falla o el usuario no tiene ninguna registrada.
        biometricOnly: false,
        // Sobrevive a que la app pase un momento a segundo plano mientras el
        // sistema muestra su dialogo.
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
