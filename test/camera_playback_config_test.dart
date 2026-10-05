import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/screens/camera/camera_screen.dart';

void main() {
  test('Android video surface is attached before hardware decoder startup', () {
    expect(
      cameraVideoConfiguration.androidAttachSurfaceAfterVideoParameters,
      isFalse,
    );
    expect(cameraVideoConfiguration.enableHardwareAcceleration, isTrue);
  });

  test('AI frame request keeps the camera id free of query parameters', () {
    final url = buildAiFrameUrl(
      'https://api-ai.vigishield.app/ai',
      '1919e584-145c-4126-ae60-03e270dbd1f7',
    );
    expect(
      url,
      'https://api-ai.vigishield.app/ai/frame/'
      '1919e584-145c-4126-ae60-03e270dbd1f7',
    );
    expect(Uri.parse(url).query, isEmpty);
  });
}
