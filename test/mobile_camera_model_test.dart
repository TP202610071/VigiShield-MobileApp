import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';

void main() {
  test('camera notifications default on and mobile source needs no IP', () {
    final camera = CameraConfigModel.fromJson({'id': 'mobile', 'streamMode': 'MobileWebRtc'});
    expect(camera.notificationsEnabled, isTrue);
    expect(camera.isMobileWebRtc, isTrue);
    expect(CameraConfigModel.fromJson({'id': 'ip', 'notificationsEnabled': false}).notificationsEnabled, isFalse);
    const request = SaveCameraRequest(name: 'Phone', streamMode: 'MobileWebRtc');
    expect(request.toJson()['cameraIp'], isNull);
    expect(request.toJson()['streamMode'], 'MobileWebRtc');
  });
}
