import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  AppConstants._();

  // ── App info ───────────────────────────────────────────────────────────────
  /// Version que se muestra en Ajustes. NO se escribe a mano: la rellena
  /// [loadAppVersion] leyendo el paquete instalado, asi que siempre coincide
  /// con `version:` del pubspec y nunca se queda desfasada.
  static String appVersion = _versionPorDefecto;
  static const String _versionPorDefecto = '0.9.0';

  /// Lee la version real del paquete. Se llama una vez al arrancar.
  static Future<void> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) appVersion = info.version;
    } catch (_) {
      // En tests no hay plataforma: se queda el valor por defecto.
    }
  }

  // ── Storage keys ───────────────────────────────────────────────────────────
  static const String tokenKey = 'vigishield_access_token';
  static const String serverUrlKey = 'vigishield_server_url';
  static const String localeKey = 'vigishield_locale';
  static const String previewRoleKey = 'vigishield_preview_role';

  // ── Default server URL ─────────────────────────────────────────────────────
  // Production cloud backend — what every normal user connects to. Only an
  // administrator can change this (hidden developer screen).
  static const String defaultServerUrl = 'https://api.vigishield.app';

  // Dev-only convenience: 10.0.2.2 → host localhost on the Android EMULATOR.
  static const String defaultEmulatorUrl = 'http://10.0.2.2:5020';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
