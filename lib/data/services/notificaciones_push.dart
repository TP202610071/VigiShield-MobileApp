import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/api_client.dart';
import '../../providers/session_scoped.dart';

enum EstadoPush {
  /// Aún no se intentó (o se cerró la sesión).
  desconocido,
  /// Este teléfono recibe las alertas.
  activas,
  /// El usuario no dio permiso (se cambia en los ajustes del teléfono).
  sinPermiso,
  /// El teléfono o la app no pueden recibir push (p. ej. falta configurar Firebase en Android).
  noDisponible,
}

/// Notificaciones push de las alertas: APNs directo en iPhone y FCM en Android.
///
/// Al iniciar sesión pide permiso, obtiene el token del teléfono (código
/// nativo, canal "vigishield/push") y lo registra en el backend. Al cerrar
/// sesión lo da de baja, para que el teléfono deje de recibir las alertas de
/// esa cuenta. Tocar una notificación abre el evento.
class NotificacionesPush extends ChangeNotifier implements SessionScoped {
  NotificacionesPush(this._api, {MethodChannel? canal})
      : _canal = canal ?? const MethodChannel('vigishield/push') {
    _canal.setMethodCallHandler(_alRecibir);
  }

  final ApiClient _api;
  final MethodChannel _canal;

  EstadoPush _estado = EstadoPush.desconocido;
  EstadoPush get estado => _estado;

  String? _token;
  bool _activando = false;

  /// Lo pone main.dart: navega al evento.
  void Function(String eventId)? alAbrirEvento;

  // Un mismo toque puede llegar dos veces (al arrancar en frío y en vivo).
  String? _ultimoAbierto;
  DateTime? _ultimoAbiertoEn;

  static bool get soportado =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  static bool get _esIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Pide permiso y registra el teléfono. Se puede llamar varias veces.
  Future<void> activar({bool forzar = false}) async {
    if (!soportado || _activando || _estado == EstadoPush.activas) return;
    // Si ya lo negó, no se vuelve a preguntar solo: se pide desde Ajustes.
    if (!forzar && _estado == EstadoPush.sinPermiso) return;
    _activando = true;
    try {
      String? token;
      if (_esIos) {
        token = await _canal.invokeMethod<String>('pedirPermisoYToken');
        if (token == null) {
          _cambiar(EstadoPush.sinPermiso);
          return;
        }
      } else {
        final permiso = await Permission.notification.request();
        if (!permiso.isGranted) {
          _cambiar(EstadoPush.sinPermiso);
          return;
        }
        token = await _canal.invokeMethod<String>('token');
        if (token == null) {
          _cambiar(EstadoPush.noDisponible);
          return;
        }
      }
      await _registrar(token);
      _cambiar(EstadoPush.activas);
    } on MissingPluginException {
      _cambiar(EstadoPush.noDisponible);
    } catch (e) {
      debugPrint('Push: no se pudo activar: $e');
    } finally {
      _activando = false;
    }
  }

  Future<void> _registrar(String token) async {
    final entorno = await _canal.invokeMethod<String>('entorno') ?? 'produccion';
    await _api.post<dynamic>('/api/push/dispositivos', body: {
      'token': token,
      'plataforma': _esIos ? 'ios' : 'android',
      'entorno': entorno,
    });
    _token = token;
  }

  /// El evento de la notificación que abrió la app en frío, si hubo.
  Future<String?> eventoInicial() async {
    if (!soportado) return null;
    try {
      return await _canal.invokeMethod<String>('eventoInicial');
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _alRecibir(MethodCall llamada) async {
    switch (llamada.method) {
      case 'tokenRenovado':
        final token = llamada.arguments as String?;
        if (token != null && _token != null && token != _token) {
          try {
            await _registrar(token);
          } catch (_) {}
        }
      case 'abrirEvento':
        final id = llamada.arguments as String?;
        if (id != null) abrir(id);
        // Ya se atendió: que no vuelva a salir como evento inicial.
        unawaited(eventoInicial());
    }
    return null;
  }

  @visibleForTesting
  void abrir(String id) {
    final ahora = DateTime.now();
    if (id == _ultimoAbierto && _ultimoAbiertoEn != null && ahora.difference(_ultimoAbiertoEn!).inSeconds < 5) {
      return;
    }
    _ultimoAbierto = id;
    _ultimoAbiertoEn = ahora;
    alAbrirEvento?.call(id);
  }

  /// «Enviar notificación de prueba» de Ajustes.
  Future<({int dispositivos, int enviados, bool configurado})> enviarPrueba() async {
    final r = await _api.post<Map<String, dynamic>>('/api/push/prueba');
    return (
      dispositivos: (r['dispositivos'] as num?)?.toInt() ?? 0,
      enviados: (r['enviados'] as num?)?.toInt() ?? 0,
      configurado: r['configurado'] != false,
    );
  }

  void _cambiar(EstadoPush e) {
    if (_estado == e) return;
    _estado = e;
    notifyListeners();
  }

  /// Al cerrar sesión: el teléfono deja de recibir las alertas de esta cuenta.
  @override
  void clearSession() {
    final token = _token;
    _token = null;
    _estado = EstadoPush.desconocido;
    notifyListeners();
    if (token != null) {
      unawaited(_api
          .post<dynamic>('/api/push/dispositivos/baja', body: {'token': token})
          .then((_) {}, onError: (_) {}));
    }
  }
}
