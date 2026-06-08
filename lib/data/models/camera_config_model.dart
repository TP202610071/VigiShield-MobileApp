class CameraConfigModel {
  final String id;
  final String name;
  final bool isDefault;
  final String streamMode; // 'DirectRtsp' or 'RtmpRelay'
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

  const CameraConfigModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.streamMode,
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
  });

  bool get isDirectRtsp => streamMode == 'DirectRtsp';
  bool get isRtmpRelay => streamMode == 'RtmpRelay';

  factory CameraConfigModel.fromJson(Map<String, dynamic> json) {
    return CameraConfigModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Cámara',
      isDefault: json['isDefault'] as bool? ?? false,
      streamMode: json['streamMode'] as String? ?? 'DirectRtsp',
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
