class AppConstants {
  AppConstants._();

  // ── App info ───────────────────────────────────────────────────────────────
  static const String appVersion = '0.1.0';

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
