class AppConstants {
  AppConstants._();

  // ── Storage keys ───────────────────────────────────────────────────────────
  static const String tokenKey = 'vigishield_access_token';
  static const String serverUrlKey = 'vigishield_server_url';

  // ── Default server URL ─────────────────────────────────────────────────────
  // 10.0.2.2 → host localhost when running on the Android EMULATOR.
  // On a real device you must change this to your PC's local IP in Settings.
  static const String defaultEmulatorUrl = 'http://10.0.2.2:5020';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
