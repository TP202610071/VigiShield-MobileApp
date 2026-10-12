import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../storage/auth_storage.dart';
import 'app_theme.dart';

enum ModoTema { sistema, claro, oscuro }

/// Modo claro u oscuro de la app, guardado en el teléfono.
///
/// Los colores de [AppColors] no son de `Theme.of(context)` sino globales, así
/// que al cambiar de modo no basta con un tema nuevo: se cambia la paleta y se
/// marca para reconstruir todo el árbol de widgets, sin perder la navegación
/// ni el estado de las pantallas.
class TemaProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _clave = 'vigishield_tema';

  /// Por defecto, el oscuro de siempre: el claro se elige en Ajustes.
  static const ModoTema porDefecto = ModoTema.oscuro;

  final AuthStorage _storage;
  ModoTema _modo;

  TemaProvider(this._storage, this._modo) {
    WidgetsBinding.instance.addObserver(this);
    aplicarInicial(_modo);
  }

  ModoTema get modo => _modo;
  bool get esClaro => AppColors.esClaro;

  /// Modo leído al arrancar (lo llena [prepararInicio] en `main`).
  static ModoTema inicial = porDefecto;

  static Future<void> prepararInicio(AuthStorage storage) async {
    try {
      inicial = await cargar(storage);
    } catch (_) {
      inicial = porDefecto;
    }
    aplicarInicial(inicial);
  }

  static Future<ModoTema> cargar(AuthStorage storage) async {
    final valor = await storage.readValue(_clave);
    return ModoTema.values.firstWhere((m) => m.name == valor, orElse: () => porDefecto);
  }

  /// Fija la paleta antes de construir la app, para que no parpadee.
  static void aplicarInicial(ModoTema modo) {
    AppColors.usarModoClaro(_claroPara(modo));
    SystemChrome.setSystemUIOverlayStyle(AppTheme.barraDeEstado);
  }

  static bool _claroPara(ModoTema modo) => switch (modo) {
        ModoTema.claro => true,
        ModoTema.oscuro => false,
        ModoTema.sistema =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light,
      };

  Future<void> cambiar(ModoTema modo) async {
    if (modo == _modo) return;
    _modo = modo;
    _aplicar();
    try {
      await _storage.writeValue(_clave, modo.name);
    } catch (_) {
      // Si no se puede guardar, el modo vale hasta cerrar la app.
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_modo == ModoTema.sistema) _aplicar();
  }

  void _aplicar() {
    final claro = _claroPara(_modo);
    final cambia = claro != AppColors.esClaro;
    AppColors.usarModoClaro(claro);
    SystemChrome.setSystemUIOverlayStyle(AppTheme.barraDeEstado);
    notifyListeners();
    if (cambia) WidgetsBinding.instance.addPostFrameCallback((_) => reconstruirTodo());
  }

  /// Marca todos los widgets para volver a construirse con la paleta nueva.
  static void reconstruirTodo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(marcar);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
