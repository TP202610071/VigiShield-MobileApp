import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/constants/app_constants.dart';
import 'package:vigishield_mobile_app/data/models/user_model.dart';
import 'package:vigishield_mobile_app/screens/settings/camera_setup_screen.dart';

void main() {
  test('la cámara IP exige nombre, dirección y puerto válidos', () {
    expect(validarNombreCamara(''), isNotNull);
    expect(validarNombreCamara('   '), isNotNull);
    expect(validarNombreCamara('Entrada'), isNull);
    expect(validarIpCamara(''), isNotNull);
    expect(validarIpCamara('hola'), isNotNull);
    expect(validarIpCamara('999.1.1.1'), isNotNull);
    expect(validarIpCamara('192.168.1.82'), isNull);
    expect(validarIpCamara('camara.midominio.com'), isNull);
    expect(validarIpCamara('demo'), isNull);
    expect(validarPuertoCamara(''), isNotNull);
    expect(validarPuertoCamara('0'), isNotNull);
    expect(validarPuertoCamara('70000'), isNotNull);
    expect(validarPuertoCamara('554'), isNull);
  });

  test('solo cuenta como aceptada la versión vigente de los términos', () {
    UserModel u(String? v) => UserModel(id: '1', email: 'a@b.c', name: 'A', role: 'Primary',
        householdId: 'h', createdAt: DateTime(2026), termsVersion: v);
    expect(u(null).aceptoTerminosVigentes, isFalse);
    expect(u('2020-01-01').aceptoTerminosVigentes, isFalse);
    expect(u(kVersionTerminos).aceptoTerminosVigentes, isTrue);
  });
}
