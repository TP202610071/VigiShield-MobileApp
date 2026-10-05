import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/data/models/zone_model.dart';

void main() {
  const poli = '[[0.1,0.1],[0.5,0.1],[0.5,0.6]]';

  test('lee las zonas guardadas en PascalCase', () {
    final z = parseZonesJson('{"Version":1,"Zones":[{"Id":"z1","Type":"door","Name":"Puerta","Polygon":$poli}]}');
    expect(z, hasLength(1));
    expect(z.first.type, 'door');
    expect(z.first.name, 'Puerta');
  });

  test('lee las zonas en camelCase', () {
    final z = parseZonesJson('{"version":1,"zones":[{"id":"z1","type":"street","name":"Calle","polygon":$poli}]}');
    expect(z.single.type, 'street');
  });
}
