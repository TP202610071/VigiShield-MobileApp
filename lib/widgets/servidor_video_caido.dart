import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../data/models/camera_config_model.dart';

/// Aviso a pantalla completa cuando el servidor de video está apagado.
///
/// El video y la IA corren en una máquina virtual que se apaga cuando no hay
/// pruebas, para no gastar créditos. Con ella apagada la pestaña Cámara se
/// quedaba en «Conectando…» para siempre. Este widget pregunta, con un tiempo
/// corto, si el servidor de video responde; si no responde pero el backend sí
/// (o sea, hay internet), tapa el video con una explicación y vuelve a probar
/// solo cada pocos segundos. Si responde, no dibuja nada.
///
/// Va encima del contenido de la pestaña y debajo de sus barras, así que se
/// puede seguir cambiando de cámara o de modo.
class ServidorVideoCaido extends StatefulWidget {
  final CameraConfigModel? camara;
  const ServidorVideoCaido({super.key, required this.camara});

  /// Servidor de video de la cámara (el host de su HLS o de su RTSP).
  static String? hostDe(CameraConfigModel? c) {
    for (final url in [c?.hlsViewUrl, c?.mediaMtxRtspUrl]) {
      if (url == null || url.isEmpty) continue;
      final host = Uri.tryParse(url)?.host;
      if (host != null && host.isNotEmpty) return host;
    }
    return null;
  }

  @override
  State<ServidorVideoCaido> createState() => _ServidorVideoCaidoState();
}

class _ServidorVideoCaidoState extends State<ServidorVideoCaido> {
  static const _espera = Duration(seconds: 6);
  bool _apagado = false;
  bool _comprobando = false;
  Timer? _timer;
  String? _host;

  @override
  void initState() {
    super.initState();
    _host = ServidorVideoCaido.hostDe(widget.camara);
    _comprobar();
  }

  @override
  void didUpdateWidget(covariant ServidorVideoCaido oldWidget) {
    super.didUpdateWidget(oldWidget);
    final host = ServidorVideoCaido.hostDe(widget.camara);
    if (host != _host) {
      _host = host;
      _comprobar();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Dio get _dio => Dio(BaseOptions(connectTimeout: _espera, receiveTimeout: _espera, sendTimeout: _espera));

  /// true si respondió algo (cualquier código HTTP); false si no se pudo conectar.
  Future<bool> _responde(String url) async {
    try {
      await _dio.head(url, options: Options(validateStatus: (_) => true, followRedirects: false));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _comprobar() async {
    _timer?.cancel();
    final host = _host;
    if (host == null || _comprobando) return;
    _comprobando = true;
    final base = context.read<ApiClient>().currentBaseUrl;
    var apagado = false;
    if (!await _responde('https://$host/')) {
      // Sin respuesta del servidor de video: solo es "apagado" si el backend
      // sí responde; si tampoco, es la red del teléfono y lo explica la app.
      apagado = await _responde('$base/health');
    }
    _comprobando = false;
    if (!mounted) return;
    if (apagado != _apagado) setState(() => _apagado = apagado);
    _timer = Timer(apagado ? const Duration(seconds: 20) : const Duration(seconds: 60), _comprobar);
  }

  @override
  Widget build(BuildContext context) {
    if (!_apagado) return const SizedBox.shrink();
    final s = context.l10n;
    return Positioned.fill(
      child: Container(
        color: AppColors.background,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.warningAmber, size: 52),
          const SizedBox(height: 16),
          Text(s.servidorApagadoTitulo,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(s.servidorApagadoTexto,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _comprobando ? null : _comprobar,
            icon: const Icon(Icons.refresh, color: AppColors.accent, size: 18),
            label: Text(s.servidorApagadoReintentar,
                style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.accent)),
          ),
        ]),
      ),
    );
  }
}

extension ServidorVideoStrings on AppStrings {
  String get servidorApagadoTitulo => en ? 'The video server is paused' : 'El servidor de video está en pausa';
  String get servidorApagadoTexto => en
      ? 'To save costs, the server that receives and analyzes the video is turned off when no tests are '
          'running. Your cameras, faces and history are still saved. Try again later; this screen will '
          'update by itself when the server is back.'
      : 'Para ahorrar costos, el servidor que recibe y analiza el video se apaga cuando no hay pruebas en '
          'curso. Tus cámaras, rostros e historial siguen guardados. Vuelve a intentarlo más tarde; esta '
          'pantalla se actualiza sola cuando el servidor vuelva.';
  String get servidorApagadoReintentar => en ? 'Try again' : 'Reintentar';
}
