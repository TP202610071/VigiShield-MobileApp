class SecurityEventModel {
  final String id;
  final String householdId;
  final String eventType;
  final double? confidenceScore;
  final String? imageCapturePath;
  final String? videoClipPath;
  final String? personName;
  final String riskLevel;
  final bool isNighttime;
  final DateTime createdAt;

  const SecurityEventModel({
    required this.id,
    required this.householdId,
    required this.eventType,
    this.confidenceScore,
    this.imageCapturePath,
    this.videoClipPath,
    this.personName,
    required this.riskLevel,
    required this.isNighttime,
    required this.createdAt,
  });

  factory SecurityEventModel.fromJson(Map<String, dynamic> json) => SecurityEventModel(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        eventType: json['eventType'] as String,
        confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
        imageCapturePath: json['imageCapturePath'] as String?,
        videoClipPath: json['videoClipPath'] as String?,
        personName: json['personName'] as String?,
        riskLevel: json['riskLevel'] as String,
        isNighttime: json['isNighttime'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Simulated demo event — used for MVP presentation only.
  factory SecurityEventModel.simulated() => SecurityEventModel(
        id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
        householdId: 'demo',
        eventType: 'LockpickingAttempt',
        confidenceScore: 0.94,
        riskLevel: 'Critical',
        isNighttime: false,
        createdAt: DateTime.now().toUtc(),
      );
}

class EventListResult {
  final List<SecurityEventModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const EventListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory EventListResult.fromJson(Map<String, dynamic> json) => EventListResult(
        items: (json['items'] as List)
            .map((e) => SecurityEventModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
        totalPages: json['totalPages'] as int,
      );
}
