class SystemStatusModel {
  final bool isMonitoringActive;
  final DateTime? lastEventAt;
  final int eventsTodayCount;
  final String streamUrl;

  const SystemStatusModel({
    required this.isMonitoringActive,
    this.lastEventAt,
    required this.eventsTodayCount,
    required this.streamUrl,
  });

  factory SystemStatusModel.fromJson(Map<String, dynamic> json) => SystemStatusModel(
        isMonitoringActive: json['isMonitoringActive'] as bool,
        lastEventAt: json['lastEventAt'] != null
            ? DateTime.parse(json['lastEventAt'] as String)
            : null,
        eventsTodayCount: json['eventsTodayCount'] as int,
        streamUrl: json['streamUrl'] as String? ?? '',
      );
}
