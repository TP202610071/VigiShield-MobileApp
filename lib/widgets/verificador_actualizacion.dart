import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';

/// Archivo con las versiones publicadas. Es estático en la web de VigiShield
/// (`VigiShield_Main_Backend/web/app-version.json`), así que se cambia sin
/// tocar el backend ni publicar otra app.
const String kUrlVersionApp = 'https://vigishield.app/app-version.json';

/// TestFlight, por si la URL del archivo no abre.
const String _urlTestFlight = 'https://apps.apple.com/app/testflight/id899247664';

enum TipoActualizacion { ninguna, opcional, obligatoria }

/// Lo que dice `app-version.json` para una plataforma.
///
/// - `minimo`: el build más antiguo que todavía funciona con el servidor. Uno
///   menor ya no puede usarse: se pide actualizar sí o sí.
/// - `ultimo`: el build más reciente publicado. Uno menor ve un aviso que se
///   puede cerrar.
class VersionPublicada {
  final int minimo;
  final int ultimo;
  final String url;
  final String notasEs;
  final String notasEn;

  const VersionPublicada({
    required this.minimo,
    required this.ultimo,
    required this.url,
    this.notasEs = '',
    this.notasEn = '',
  });

  /// null si el archivo no trae la plataforma o viene mal formado: en ese caso
  /// la app no pide nada.
  static VersionPublicada? desdeJson(Object? json, String plataforma) {
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {
        return null;
      }
    }
    if (json is! Map) return null;
    final p = json[plataforma];
    if (p is! Map) return null;
    int entero(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    final notas = p['notas'];
    return VersionPublicada(
      minimo: entero(p['minimo']),
      ultimo: entero(p['ultimo']),
      url: (p['url'] as String?)?.trim() ?? '',
      notasEs: notas is Map ? '${notas['es'] ?? ''}'.trim() : '',
      notasEn: notas is Map ? '${notas['en'] ?? ''}'.trim() : '',
    );
  }

  /// Qué pedirle a quien tiene instalado [build]. Si el build no se conoce
  /// (0), no se pide nada: nunca se bloquea por un dato dudoso.
  TipoActualizacion para(int build) {
    if (build <= 0) return TipoActualizacion.ninguna;
    if (build < minimo) return TipoActualizacion.obligatoria;
    if (build < ultimo) return TipoActualizacion.opcional;
    return TipoActualizacion.ninguna;
  }

  String notas(bool en) => en && notasEn.isNotEmpty ? notasEn : notasEs;
}

/// Revisa si hay una versión nueva de la app y, si la instalada ya no es
/// compatible, tapa todo con una pantalla que solo deja actualizar.
///
/// Por ahora solo en iOS: ahí todos instalan por TestFlight y pueden
/// actualizar solos. En Android la app se reparte a mano, así que obligar a
/// actualizar dejaría a la gente sin forma de seguir.
///
/// Si no hay internet o el archivo falla, no pide nada. Revisa al abrir la app
/// y al volver a ella (como mucho cada 30 minutos).
class VerificadorActualizacion extends StatefulWidget {
  final Widget child;

  /// Para pruebas: reemplazan la descarga del archivo, el build instalado y la
  /// plataforma.
  final Future<Object?> Function()? cargar;
  final Future<int> Function()? buildInstalado;
  final bool? aplica;

  const VerificadorActualizacion({
    super.key,
    required this.child,
    this.cargar,
    this.buildInstalado,
    this.aplica,
  });

  static bool get aplicaEnEstaPlataforma => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  State<VerificadorActualizacion> createState() => _VerificadorActualizacionState();
}

class _VerificadorActualizacionState extends State<VerificadorActualizacion> with WidgetsBindingObserver {
  static const _cadaCuanto = Duration(minutes: 30);
  static const _claveDescartada = 'actualizacion_descartada_ios';
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  TipoActualizacion _tipo = TipoActualizacion.ninguna;
  VersionPublicada? _version;
  DateTime? _ultimaRevision;
  bool _revisando = false;

  bool get _aplica => widget.aplica ?? VerificadorActualizacion.aplicaEnEstaPlataforma;

  @override
  void initState() {
    super.initState();
    if (!_aplica) return;
    WidgetsBinding.instance.addObserver(this);
    _revisar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final ultima = _ultimaRevision;
    final obligatoria = _tipo == TipoActualizacion.obligatoria;
    if (obligatoria || ultima == null || DateTime.now().difference(ultima) >= _cadaCuanto) _revisar();
  }

  Future<Object?> _descargar() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    // El parámetro evita que una caché intermedia devuelva un archivo viejo.
    final r = await dio.get<Object?>(kUrlVersionApp,
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
    return r.data;
  }

  Future<int> _build() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  Future<String?> _leerDescartada() async {
    try {
      return await _storage.read(key: _claveDescartada);
    } catch (_) {
      return null;
    }
  }

  Future<void> _revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      final datos = await (widget.cargar ?? _descargar)();
      final version = VersionPublicada.desdeJson(datos, 'ios');
      final build = await (widget.buildInstalado ?? _build)();
      var tipo = version?.para(build) ?? TipoActualizacion.ninguna;
      // Un aviso opcional cerrado no vuelve hasta que salga otro build.
      if (tipo == TipoActualizacion.opcional && await _leerDescartada() == '${version!.ultimo}') {
        tipo = TipoActualizacion.ninguna;
      }
      _ultimaRevision = DateTime.now();
      if (mounted) {
        setState(() {
          _version = version;
          _tipo = tipo;
        });
      }
    } catch (_) {
      // Sin red o archivo con error: se deja lo que había y se reintenta luego.
    } finally {
      _revisando = false;
    }
  }

  Future<void> _actualizar() async {
    final url = _version?.url ?? '';
    for (final destino in [url, _urlTestFlight]) {
      final uri = Uri.tryParse(destino);
      if (uri == null || !uri.hasScheme) continue;
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Se prueba con la siguiente.
      }
    }
  }

  Future<void> _descartar() async {
    final ultimo = _version?.ultimo;
    setState(() => _tipo = TipoActualizacion.ninguna);
    if (ultimo == null) return;
    try {
      await _storage.write(key: _claveDescartada, value: '$ultimo');
    } catch (_) {
      // Si no se puede guardar, el aviso vuelve la próxima vez; no es grave.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tipo == TipoActualizacion.ninguna) return widget.child;
    final s = context.watch<LocaleProvider>().strings;
    final notas = _version?.notas(s.en) ?? '';
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (_tipo == TipoActualizacion.obligatoria)
        Positioned.fill(child: _PantallaObligatoria(s: s, notas: notas, alActualizar: _actualizar, alRevisar: _revisar))
      else
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _AvisoOpcional(s: s, notas: notas, alActualizar: _actualizar, alCerrar: _descartar),
        ),
    ]);
  }
}

class _PantallaObligatoria extends StatelessWidget {
  final AppStrings s;
  final String notas;
  final VoidCallback alActualizar;
  final VoidCallback alRevisar;

  const _PantallaObligatoria({
    required this.s,
    required this.notas,
    required this.alActualizar,
    required this.alRevisar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.system_update_rounded, color: AppColors.accent, size: 44),
                  const SizedBox(height: 16),
                  Text(s.actualizacionObligatoriaTitulo,
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(s.actualizacionObligatoriaTexto,
                      style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
                  if (notas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(notas,
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(onPressed: alActualizar, child: Text(s.actualizacionBoton)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: alRevisar,
                      child: Text(s.actualizacionRevisar,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoOpcional extends StatelessWidget {
  final AppStrings s;
  final String notas;
  final VoidCallback alActualizar;
  final VoidCallback alCerrar;

  const _AvisoOpcional({
    required this.s,
    required this.notas,
    required this.alActualizar,
    required this.alCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: AppColors.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.system_update_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.actualizacionOpcionalTitulo,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ]),
                if (notas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(notas,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  ),
                ],
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: alCerrar,
                    child: Text(s.actualizacionAhoraNo, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                  TextButton(
                    onPressed: alActualizar,
                    child: Text(s.actualizacionBoton, style: const TextStyle(color: AppColors.accent)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension ActualizacionStrings on AppStrings {
  String get actualizacionObligatoriaTitulo => en ? 'Update required' : 'Actualización necesaria';
  String get actualizacionObligatoriaTexto => en
      ? 'This version of VigiShield no longer works with the server. Install the latest version to keep '
          'using it. Your cameras, faces and history are still saved.'
      : 'Esta versión de VigiShield ya no funciona con el servidor. Instala la versión más reciente para '
          'seguir usándola. Tus cámaras, rostros e historial siguen guardados.';
  String get actualizacionOpcionalTitulo =>
      en ? 'A new version of VigiShield is available' : 'Hay una versión nueva de VigiShield';
  String get actualizacionBoton => en ? 'Update' : 'Actualizar';
  String get actualizacionAhoraNo => en ? 'Not now' : 'Ahora no';
  String get actualizacionRevisar => en ? 'Check again' : 'Comprobar de nuevo';
}
