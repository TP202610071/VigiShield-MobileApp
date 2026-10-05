class CameraConfigModel {
  final String id;
  final String name;
  final bool isDefault;
  final String streamMode; // DirectRtsp, RtmpRelay or MobileWebRtc
  final bool notificationsEnabled;
  /// false = la IA no la procesa. Es lo unico que ahorra recursos de verdad.
  final bool isActive;
  final String? cameraIp;
  final int cameraPort;
  final String? cameraPath;
  final String? cameraUsername;
  final bool hasPassword;
  final String? streamKey;
  final String? rtmpPushUrl;
  final String? hlsViewUrl;
  final String? rtspUrl;
  final String? mediaMtxRtspUrl;
  final bool isConfigured;
  final DateTime? lastVerifiedAt;
  // Zonas de interés (ROI) dibujadas por el usuario — JSON crudo, o null.
  final String? zonesJson;
  /// Cámara interna que reproduce un video de ejemplo. No es del usuario: no
  /// aparece en «Mis cámaras» y desaparece al terminar su sesión.
  final bool isSample;
  final DateTime? sampleUntil;
  final String? sampleTitle;
  final String? sampleTitleEn;

  const CameraConfigModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.streamMode,
    this.notificationsEnabled = true,
    this.isActive = true,
    this.cameraIp,
    required this.cameraPort,
    this.cameraPath,
    this.cameraUsername,
    required this.hasPassword,
    this.streamKey,
    this.rtmpPushUrl,
    this.hlsViewUrl,
    this.rtspUrl,
    this.mediaMtxRtspUrl,
    required this.isConfigured,
    this.lastVerifiedAt,
    this.zonesJson,
    this.isSample = false,
    this.sampleUntil,
    this.sampleTitle,
    this.sampleTitleEn,
  });

  /// Título del video de ejemplo en el idioma de la app.
  String? sampleTitleFor({required bool english}) =>
      english ? (sampleTitleEn ?? sampleTitle) : sampleTitle;

  /// Tiempo que le queda a la sesión del video de ejemplo.
  Duration get sampleRemaining {
    final fin = sampleUntil;
    if (fin == null) return Duration.zero;
    final queda = fin.difference(DateTime.now());
    return queda.isNegative ? Duration.zero : queda;
  }

  bool get isDirectRtsp => streamMode == 'DirectRtsp';
  bool get isRtmpRelay => streamMode == 'RtmpRelay';
  bool get isMobileWebRtc => streamMode == 'MobileWebRtc';

  factory CameraConfigModel.fromJson(Map<String, dynamic> json) {
    return CameraConfigModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Cámara',
      isDefault: json['isDefault'] as bool? ?? false,
      streamMode: json['streamMode'] as String? ?? 'DirectRtsp',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      cameraIp: json['cameraIp'] as String?,
      cameraPort: (json['cameraPort'] as int?) ?? 554,
      cameraPath: json['cameraPath'] as String?,
      cameraUsername: json['cameraUsername'] as String?,
      hasPassword: json['hasPassword'] as bool? ?? false,
      streamKey: json['streamKey'] as String?,
      rtmpPushUrl: json['rtmpPushUrl'] as String?,
      hlsViewUrl: json['hlsViewUrl'] as String?,
      rtspUrl: json['rtspUrl'] as String?,
      mediaMtxRtspUrl: json['mediaMtxRtspUrl'] as String?,
      isConfigured: json['isConfigured'] as bool? ?? false,
      lastVerifiedAt: json['lastVerifiedAt'] != null
          ? DateTime.tryParse(json['lastVerifiedAt'] as String)
          : null,
      zonesJson: json['zonesJson'] as String?,
      isSample: json['isSample'] as bool? ?? false,
      sampleUntil: json['sampleUntil'] != null
          ? DateTime.tryParse(json['sampleUntil'] as String)
          : null,
      sampleTitle: json['sampleTitle'] as String?,
      sampleTitleEn: json['sampleTitleEn'] as String?,
    );
  }
}

class SaveCameraRequest {
  final String name;
  final String streamMode;
  final String? cameraIp;
  final int cameraPort;
  final String? cameraPath;
  final String? cameraUsername;
  final String? cameraPassword;
  final String? customHlsUrl;
  final bool isDefault;

  const SaveCameraRequest({
    required this.name,
    required this.streamMode,
    this.cameraIp,
    this.cameraPort = 554,
    this.cameraPath,
    this.cameraUsername,
    this.cameraPassword,
    this.customHlsUrl,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'streamMode': streamMode,
        'cameraIp': cameraIp,
        'cameraPort': cameraPort,
        'cameraPath': cameraPath,
        'cameraUsername': cameraUsername,
        'cameraPassword': cameraPassword,
        'customHlsUrl': customHlsUrl,
        'isDefault': isDefault,
      };
}

/// Sesión en curso del video de ejemplo (ver CameraService en el backend).
class SampleVideoSession {
  final CameraConfigModel camera;
  final String videoKey;
  final int seen;
  final int total;

  const SampleVideoSession({
    required this.camera,
    required this.videoKey,
    required this.seen,
    required this.total,
  });

  factory SampleVideoSession.fromJson(Map<String, dynamic> json) =>
      SampleVideoSession(
        camera: CameraConfigModel.fromJson(json['camera'] as Map<String, dynamic>),
        videoKey: json['videoKey'] as String? ?? '',
        seen: (json['seen'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}
