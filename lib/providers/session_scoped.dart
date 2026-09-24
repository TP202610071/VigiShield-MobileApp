import 'package:flutter/foundation.dart';

/// Estado que pertenece a la sesión de un usuario y no debe sobrevivir a un
/// cierre de sesión.
///
/// Los providers viven en `main.dart` durante toda la vida de la app, así que
/// al cerrar sesión conservaban las cámaras y los eventos de la cuenta
/// anterior: quien entraba con otra cuenta seguía viendo el video en vivo y los
/// filtros de la anterior hasta que algo forzaba una recarga.
abstract class SessionScoped implements Listenable {
  /// Deja el provider como recién creado. Se llama al cerrar sesión.
  void clearSession();
}
