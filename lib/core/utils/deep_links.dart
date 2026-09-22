/// Guarda el destino de un enlace capturado al arrancar en frío, antes de que el
/// router y la sesión estén listos, para que la pantalla de bienvenida navegue
/// allí una vez resuelta la autenticación. Los enlaces en caliente (app ya
/// abierta) se navegan directamente desde main.dart.
class DeepLinks {
  /// Ruta interna pendiente, p. ej. `/history/<id>`, `/reset-password?token=…`
  /// o `/invitacion?token=…`.
  static String? pendingRoute;
}
