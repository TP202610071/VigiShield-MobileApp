class AlertConfigModel {
  final bool unknownPersonEnabled;
  final bool forcedAccessEnabled;
  final bool tailgatingEnabled;
  final bool climbingEnabled;
  final bool aggressionEnabled;
  final int tailgatingThresholdSeconds;
  final String? nighttimeStart;
  final String? nighttimeEnd;
  final bool whatsAppEnabled;

  /// Todos los tipos que el hogar puede gobernar. Los envía el backend para no
  /// mantener la lista duplicada en la app.
  final List<String> availableEventTypes;

  /// Los que están apagados. Es la fuente de verdad: los cinco booleanos de
  /// arriba agrupaban varios tipos bajo un mismo interruptor y dejaban algunos
  /// (como "Riesgo de intrusión") sin forma de activarse o desactivarse.
  final List<String> disabledEventTypes;

  const AlertConfigModel({
    required this.unknownPersonEnabled,
    required this.forcedAccessEnabled,
    required this.tailgatingEnabled,
    required this.climbingEnabled,
    required this.aggressionEnabled,
    required this.tailgatingThresholdSeconds,
    this.nighttimeStart,
    this.nighttimeEnd,
    required this.whatsAppEnabled,
    this.availableEventTypes = const [],
    this.disabledEventTypes = const [],
  });

  bool isEnabled(String type) => !disabledEventTypes.contains(type);

  /// Enciende o apaga un tipo concreto.
  AlertConfigModel toggle(String type, bool enabled) {
    final off = [...disabledEventTypes];
    off.remove(type);
    if (!enabled) off.add(type);
    return copyWith(disabledEventTypes: off);
  }

  /// Apaga o enciende todos de golpe.
  AlertConfigModel setAll(bool enabled) =>
      copyWith(disabledEventTypes: enabled ? const [] : [...availableEventTypes]);

  static List<String> _strings(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  factory AlertConfigModel.fromJson(Map<String, dynamic> json) => AlertConfigModel(
        unknownPersonEnabled: json['unknownPersonEnabled'] as bool,
        forcedAccessEnabled: json['forcedAccessEnabled'] as bool,
        tailgatingEnabled: json['tailgatingEnabled'] as bool,
        climbingEnabled: json['climbingEnabled'] as bool,
        aggressionEnabled: json['aggressionEnabled'] as bool,
        tailgatingThresholdSeconds: json['tailgatingThresholdSeconds'] as int,
        nighttimeStart: json['nighttimeStart'] as String?,
        nighttimeEnd: json['nighttimeEnd'] as String?,
        whatsAppEnabled: json['whatsAppEnabled'] as bool,
        availableEventTypes: _strings(json['availableEventTypes']),
        disabledEventTypes: _strings(json['disabledEventTypes']),
      );

  Map<String, dynamic> toJson() => {
        'unknownPersonEnabled': unknownPersonEnabled,
        'forcedAccessEnabled': forcedAccessEnabled,
        'tailgatingEnabled': tailgatingEnabled,
        'climbingEnabled': climbingEnabled,
        'aggressionEnabled': aggressionEnabled,
        'tailgatingThresholdSeconds': tailgatingThresholdSeconds,
        'nighttimeStart': nighttimeStart,
        'nighttimeEnd': nighttimeEnd,
        'whatsAppEnabled': whatsAppEnabled,
        'disabledEventTypes': disabledEventTypes,
      };

  AlertConfigModel copyWith({
    bool? unknownPersonEnabled,
    bool? forcedAccessEnabled,
    bool? tailgatingEnabled,
    bool? climbingEnabled,
    bool? aggressionEnabled,
    int? tailgatingThresholdSeconds,
    bool? whatsAppEnabled,
    List<String>? disabledEventTypes,
  }) =>
      AlertConfigModel(
        unknownPersonEnabled: unknownPersonEnabled ?? this.unknownPersonEnabled,
        forcedAccessEnabled: forcedAccessEnabled ?? this.forcedAccessEnabled,
        tailgatingEnabled: tailgatingEnabled ?? this.tailgatingEnabled,
        climbingEnabled: climbingEnabled ?? this.climbingEnabled,
        aggressionEnabled: aggressionEnabled ?? this.aggressionEnabled,
        tailgatingThresholdSeconds:
            tailgatingThresholdSeconds ?? this.tailgatingThresholdSeconds,
        nighttimeStart: nighttimeStart,
        nighttimeEnd: nighttimeEnd,
        whatsAppEnabled: whatsAppEnabled ?? this.whatsAppEnabled,
        availableEventTypes: availableEventTypes,
        disabledEventTypes: disabledEventTypes ?? this.disabledEventTypes,
      );
}
