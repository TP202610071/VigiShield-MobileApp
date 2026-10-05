import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';

Map<String, dynamic> _ejemplo(Duration queda, {String key = 'ejemplo03'}) => {
      'id': 'muestra',
      'name': 'Video de ejemplo',
      'streamMode': 'DirectRtsp',
      'streamKey': key,
      'notificationsEnabled': false,
      'isSample': true,
      'sampleUntil': DateTime.now().add(queda).toUtc().toIso8601String(),
      'sampleTitle': 'Persona con linterna junto a una ventana, de noche',
      'sampleTitleEn': 'Person with a flashlight by a window at night',
    };

class _Servicio extends CameraDataService {
  _Servicio(this.queda) : super(ApiClient(AuthStorage()));
  final Duration queda;
  int detenidos = 0;

  @override
  Future<List<CameraConfigModel>> getCameras() async => [
        CameraConfigModel.fromJson(
            {'id': 'puerta', 'name': 'Puerta', 'streamMode': 'MobileWebRtc', 'isDefault': true}),
      ];

  @override
  Future<SampleVideoSession> startSampleVideo({bool otro = false}) async =>
      SampleVideoSession.fromJson({
        'camera': _ejemplo(queda, key: otro ? 'ejemplo07' : 'ejemplo03'),
        'videoKey': otro ? 'ejemplo07' : 'ejemplo03',
        'seen': otro ? 2 : 1,
        'total': 10,
      });

  @override
  Future<void> stopSampleVideo() async => detenidos++;
}

void main() {
  test('la cámara del video de ejemplo se lee con su título y su fin', () {
    final cam = CameraConfigModel.fromJson(_ejemplo(const Duration(minutes: 3)));
    expect(cam.isSample, isTrue);
    expect(cam.sampleTitleFor(english: true), 'Person with a flashlight by a window at night');
    expect(cam.sampleRemaining.inSeconds, inInclusiveRange(170, 180));
    expect(CameraConfigModel.fromJson({'id': 'x', 'streamMode': 'DirectRtsp'}).isSample, isFalse);
  });

  test('iniciar el video lo selecciona, pide el modo IA y no cuenta como cámara propia', () async {
    final camaras = CameraProvider(_Servicio(const Duration(minutes: 3)));
    await camaras.fetchCameras();
    expect(await camaras.iniciarEjemplo(), isTrue);

    expect(camaras.selectedCamera?.isSample, isTrue);
    expect(camaras.abrirEnModoIa, isTrue);
    expect(camaras.misCamaras.map((c) => c.id), ['puerta']);
    expect(camaras.ejemplosVistos, 1);

    // «Otro video»: la misma cámara interna, otro stream.
    expect(await camaras.iniciarEjemplo(otro: true), isTrue);
    expect(camaras.cameras.where((c) => c.isSample).length, 1);
    expect(camaras.selectedCamera?.streamKey, 'ejemplo07');

    await camaras.terminarEjemplo();
    expect(camaras.ejemplo, isNull);
    expect(camaras.selectedCamera?.id, 'puerta');
  });

  test('al vencer la sesión el video desaparece solo', () async {
    final camaras = CameraProvider(_Servicio(const Duration(milliseconds: 10)));
    await camaras.fetchCameras();
    await camaras.iniciarEjemplo();
    expect(camaras.ejemplo, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(camaras.ejemplo, isNull);
    expect(camaras.selectedCamera?.id, 'puerta');
  });
}
