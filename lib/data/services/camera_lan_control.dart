import 'dart:convert';

import 'package:dio/dio.dart';

/// Datos para alcanzar la cámara en la red local (los entrega el backend).
class CameraLanAccess {
  final String ip;
  final int httpPort;
  final String? username;
  final String? password;

  const CameraLanAccess({
    required this.ip,
    required this.httpPort,
    this.username,
    this.password,
  });

  factory CameraLanAccess.fromJson(Map<String, dynamic> j) => CameraLanAccess(
        ip: '${j['ip']}',
        httpPort: int.tryParse('${j['httpPort']}') ?? 80,
        username: j['username'] as String?,
        password: j['password'] as String?,
      );
}

/// Habla con el CGI de las cámaras Xiongmai/hi3510 directamente por la red
/// local, sin pasar por el backend.
///
/// Hace falta porque el backend vive en la nube y la cámara tiene una IP
/// privada (192.168.x.x): desde la VM no se alcanza, así que las lecturas
/// caducaban y los cambios nunca llegaban. El teléfono sí la alcanza cuando
/// está en el wifi de casa, que es justo cuando se ajusta la cámara.
class CameraLanControl {
  /// Corto a propósito: si la cámara no está en esta red, conviene fallar
  /// rápido y pasar al camino alternativo en vez de congelar la hoja.
  static const Duration _timeout = Duration(seconds: 4);

  static const _imageKeys = {
    'brightness', 'contrast', 'saturation', 'sharpness', 'hue',
    'wdr', 'aemode', 'imgmode', 'shutter', 'flip', 'mirror',
  };
  static const _vencKeys = {'bps', 'fps', 'gop', 'brmode'};
  static const _mainChannel = '11';

  final CameraLanAccess access;
  final Dio _dio;

  CameraLanControl(this.access, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = _timeout
      ..receiveTimeout = _timeout
      ..sendTimeout = _timeout
      ..responseType = ResponseType.plain
      ..validateStatus = ((s) => s != null && s < 500);
    final user = access.username;
    if (user != null && user.isNotEmpty) {
      final token = base64Encode(utf8.encode('$user:${access.password ?? ''}'));
      _dio.options.headers['Authorization'] = 'Basic $token';
    }
  }

  String _url(String cmd) =>
      'http://${access.ip}:${access.httpPort}/cgi-bin/hi3510/param.cgi?cmd=$cmd';

  /// El CGI responde con líneas `var clave="valor";`.
  static final _varPattern = RegExp(r'var\s+(\w+)\s*=\s*"([^"]*)";');

  /// Lee los ajustes actuales. Lanza si la cámara no contesta nada útil.
  Future<Map<String, String>> read() async {
    final out = <String, String>{};
    for (final cmd in [
      'getimageattr',
      'getvencattr&-chn=$_mainChannel',
      'getinfrared',
      'getvideoattr',
    ]) {
      try {
        final r = await _dio.get<String>(_url(cmd));
        for (final m in _varPattern.allMatches(r.data ?? '')) {
          out[m.group(1)!] = m.group(2)!;
        }
      } on DioException {
        // Un comando puede no existir según el modelo; se sigue con el resto.
      }
    }
    if (out.isEmpty) {
      throw const CameraLanUnreachable();
    }
    return out;
  }

  /// Aplica los ajustes. Lanza si la cámara no acepta alguno.
  Future<void> apply(Map<String, String> settings) async {
    final image = StringBuffer();
    final venc = StringBuffer();
    String? infrared;

    settings.forEach((key, value) {
      final k = key.trim();
      final v = Uri.encodeComponent(value.trim());
      if (_imageKeys.contains(k)) {
        image.write('&-$k=$v');
      } else if (_vencKeys.contains(k)) {
        venc.write('&-$k=$v');
      } else if (k == 'infraredstat' || k == 'night') {
        infrared = v;
      }
    });

    final cmds = <String>[
      if (image.isNotEmpty) 'setimageattr$image',
      if (venc.isNotEmpty) 'setvencattr&-chn=$_mainChannel$venc',
      if (infrared != null) 'setinfrared&-infraredstat=$infrared',
    ];
    if (cmds.isEmpty) return;

    for (final cmd in cmds) {
      try {
        await _dio.get<String>(_url(cmd));
      } on DioException {
        throw const CameraLanUnreachable();
      }
    }
  }
}

/// La cámara no respondió: casi siempre porque el teléfono no está en su red.
class CameraLanUnreachable implements Exception {
  const CameraLanUnreachable();
  @override
  String toString() => 'CameraLanUnreachable';
}
