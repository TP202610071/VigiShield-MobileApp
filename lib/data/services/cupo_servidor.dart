import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/camera_config_model.dart';

/// Lugar de una cámara en el cupo del servidor de IA (fase beta).
///
/// El servidor analiza un número limitado de cámaras a la vez. Las demás
/// esperan en cola, en orden de llegada. `estado`: activo, cola, bloqueada
/// (por el administrador) o sin_senal (nadie la transmite: no ocupa lugar).
class EstadoCupo {
  const EstadoCupo({required this.estado, this.posicion = 0, this.enCola = 0});

  final String estado;
  final int posicion;
  final int enCola;

  bool get esCola => estado == 'cola';
  bool get esBloqueada => estado == 'bloqueada';

  factory EstadoCupo.desdeJson(Map<String, dynamic> j) => EstadoCupo(
        estado: j['estado'] as String? ?? 'activo',
        posicion: (j['posicion'] as num?)?.toInt() ?? 0,
        enCola: (j['enCola'] as num?)?.toInt() ?? 0,
      );
}

/// Bloqueos que puso el administrador sobre la cuenta, el teléfono o cámaras sueltas.
class BloqueosCuenta {
  const BloqueosCuenta({this.cuenta = false, this.dispositivo = false, this.camaras = const {}, this.contacto});

  final bool cuenta;
  final bool dispositivo;
  final Set<String> camaras;
  final String? contacto;

  bool get todo => cuenta || dispositivo;
  bool bloqueada(String camaraId) => todo || camaras.contains(camaraId);
}

class CupoServidor {
  CupoServidor._();

  /// null si no se pudo saber (sin red o servidor sin cupos): la app sigue como antes.
  static Future<EstadoCupo?> consultar(ApiClient api, CameraConfigModel cam) async {
    final host = Uri.tryParse(cam.hlsViewUrl ?? '')?.host ?? '';
    if (host.isEmpty) return null;
    try {
      final r = await api.dio.get<Map<String, dynamic>>(
        'https://$host/ai/cupo/${cam.id}',
        options: _sinCache,
      );
      final d = r.data;
      return d == null ? null : EstadoCupo.desdeJson(d);
    } catch (_) {
      return null;
    }
  }

  static Future<BloqueosCuenta?> bloqueos(ApiClient api) async {
    try {
      final r = await api.dio.get<Map<String, dynamic>>('/api/bloqueos/estado', options: _sinCache);
      final d = r.data;
      if (d == null) return null;
      return BloqueosCuenta(
        cuenta: d['cuenta'] == true,
        dispositivo: d['dispositivo'] == true,
        camaras: ((d['camaras'] as List?) ?? const []).map((e) => '$e').toSet(),
        contacto: d['contacto'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static final _sinCache = Options(headers: {'Cache-Control': 'no-cache'});
}
