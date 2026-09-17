import 'dart:convert';
import 'dart:ui' show Offset;

/// Una zona de interés (ROI) dibujada por el usuario sobre el video.
/// Los puntos están NORMALIZADOS (0..1) para ser independientes de la resolución.
class Zone {
  final String id;
  String type; // door | gate | window | yard | street | custom
  String name;
  final List<Offset> points; // normalizados 0..1

  Zone({
    required this.id,
    required this.type,
    required this.name,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'polygon': points.map((p) => [p.dx, p.dy]).toList(),
      };

  factory Zone.fromJson(Map<String, dynamic> j) {
    final rawPoly = (j['polygon'] ?? j['points']) as List<dynamic>? ?? const [];
    final pts = <Offset>[];
    for (final p in rawPoly) {
      try {
        if (p is List && p.length >= 2) {
          pts.add(Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()));
        } else if (p is Map) {
          pts.add(Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()));
        }
      } catch (_) {/* ignora vértices malformados */}
    }
    return Zone(
      id: (j['id'] as String?)?.isNotEmpty == true
          ? j['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      type: (j['type'] as String?)?.toLowerCase() ?? 'custom',
      name: j['name'] as String? ?? 'Zona',
      points: pts,
    );
  }
}

/// Parsea el JSON crudo guardado en `CameraConfig.zonesJson`.
/// Acepta `{version, zones:[...]}` o una lista directa. Nunca lanza.
List<Zone> parseZonesJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    final List<dynamic> items = decoded is Map
        ? (decoded['zones'] as List<dynamic>? ?? const [])
        : (decoded is List ? decoded : const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(Zone.fromJson)
        .where((z) => z.points.length >= 3)
        .toList();
  } catch (_) {
    return [];
  }
}

/// Serializa la lista de zonas para el cuerpo del PUT del backend.
List<Map<String, dynamic>> encodeZones(List<Zone> zones) =>
    zones.where((z) => z.points.length >= 3).map((z) => z.toJson()).toList();
