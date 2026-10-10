import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/data/models/security_event_model.dart';
import 'package:vigishield_mobile_app/screens/history/rostro_del_evento.dart';

SecurityEventModel _evento(String tipo, {String? foto = 'https://bucket.vigishield.app/events/x.jpg'}) =>
    SecurityEventModel(
      id: '1', householdId: 'h', eventType: tipo, imageCapturePath: foto,
      riskLevel: 'Medium', isNighttime: false, createdAt: DateTime(2026, 10, 10));

void main() {
  test('la sección del rostro solo aplica a accesos reconocidos y desconocidos con foto', () {
    expect(RostroDelEvento.aplica(_evento('FaceRecognized')), isTrue);
    expect(RostroDelEvento.aplica(_evento('UnknownFace')), isTrue);
    expect(RostroDelEvento.aplica(_evento('Tailgating')), isFalse);
    expect(RostroDelEvento.aplica(_evento('UnknownFace', foto: null)), isFalse);
  });

  test('los textos del rostro existen en los dos idiomas', () {
    for (final s in const [AppStrings(false), AppStrings(true)]) {
      expect(s.rostroTitulo, isNotEmpty);
      expect(s.rostroEsConocido, isNotEmpty);
      expect(s.rostroRegistrado('Ana'), contains('Ana'));
    }
    expect(const AppStrings(false).rostroTitulo, isNot(const AppStrings(true).rostroTitulo));
  });
}
