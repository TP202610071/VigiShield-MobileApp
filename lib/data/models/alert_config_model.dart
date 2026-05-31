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
  });

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
      };

  AlertConfigModel copyWith({
    bool? unknownPersonEnabled,
    bool? forcedAccessEnabled,
    bool? tailgatingEnabled,
    bool? climbingEnabled,
    bool? aggressionEnabled,
    int? tailgatingThresholdSeconds,
    bool? whatsAppEnabled,
  }) =>
      AlertConfigModel(
        unknownPersonEnabled: unknownPersonEnabled ?? this.unknownPersonEnabled,
        forcedAccessEnabled: forcedAccessEnabled ?? this.forcedAccessEnabled,
        tailgatingEnabled: tailgatingEnabled ?? this.tailgatingEnabled,
        climbingEnabled: climbingEnabled ?? this.climbingEnabled,
        aggressionEnabled: aggressionEnabled ?? this.aggressionEnabled,
        tailgatingThresholdSeconds: tailgatingThresholdSeconds ?? this.tailgatingThresholdSeconds,
        nighttimeStart: nighttimeStart,
        nighttimeEnd: nighttimeEnd,
        whatsAppEnabled: whatsAppEnabled ?? this.whatsAppEnabled,
      );
}
