import 'dart:convert';

/// Preferencias de la alerta de emergencia. Se guardan en el dispositivo:
/// el volumen y el número a llamar son de quien lleva el teléfono, no del hogar.
class EmergencySettings {
  const EmergencySettings({
    this.enabled = true,
    this.phone = '',
    this.autoCall = true,
    this.volume = minVolume,
    this.sustainSeconds = 15,
    this.countdownSeconds = 30,
  });

  /// Volumen por defecto: el mínimo audible, para poder probarla sin
  /// sobresaltar a nadie. Se sube desde Ajustes.
  static const double minVolume = 0.05;
  static const sustainOptions = [5, 10, 15, 30, 60];
  static const countdownOptions = [15, 30, 60];

  final bool enabled;
  final String phone;
  final bool autoCall;
  final double volume;

  /// Segundos de riesgo sostenido antes de que salte la alerta.
  final int sustainSeconds;

  /// Segundos que tiene el usuario para desactivarla antes de la llamada.
  final int countdownSeconds;

  /// Número listo para marcar, o null si no hay uno válido.
  String? get callableNumber => normalizePhone(phone);
  bool get willCall => autoCall && callableNumber != null;

  EmergencySettings copyWith({bool? enabled, String? phone, bool? autoCall,
      double? volume, int? sustainSeconds, int? countdownSeconds}) =>
      EmergencySettings(
        enabled: enabled ?? this.enabled,
        phone: phone ?? this.phone,
        autoCall: autoCall ?? this.autoCall,
        volume: volume ?? this.volume,
        sustainSeconds: sustainSeconds ?? this.sustainSeconds,
        countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      );

  String encode() => jsonEncode({
        'enabled': enabled, 'phone': phone, 'autoCall': autoCall,
        'volume': volume, 'sustain': sustainSeconds, 'countdown': countdownSeconds,
      });

  static EmergencySettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const EmergencySettings();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      int pick(Object? v, List<int> options, int fallback) =>
          v is int && options.contains(v) ? v : fallback;
      return EmergencySettings(
        enabled: j['enabled'] as bool? ?? true,
        phone: j['phone'] as String? ?? '',
        autoCall: j['autoCall'] as bool? ?? true,
        volume: ((j['volume'] as num?)?.toDouble() ?? minVolume).clamp(0.0, 1.0),
        sustainSeconds: pick(j['sustain'], sustainOptions, 15),
        countdownSeconds: pick(j['countdown'], countdownOptions, 30),
      );
    } catch (_) {
      return const EmergencySettings();
    }
  }
}

/// Deja solo dígitos y un `+` inicial. Devuelve null si no parece un teléfono
/// personal: los números cortos (105, 911, 112...) son de emergencias públicas
/// y una app no debe llamarlos sola.
String? normalizePhone(String raw) {
  final trimmed = raw.trim();
  final plus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) return null;
  return plus ? '+$digits' : digits;
}
