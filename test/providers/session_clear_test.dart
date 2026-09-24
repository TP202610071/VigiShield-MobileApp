import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/providers/session_scoped.dart';
import 'package:flutter/foundation.dart';

/// Doble de un provider de sesión: registra cuántas veces le vaciaron el estado.
class _ProviderFalso extends ChangeNotifier implements SessionScoped {
  int vaciados = 0;
  List<String> datos = ['camara-de-la-cuenta-anterior'];

  @override
  void clearSession() {
    vaciados++;
    datos = [];
    notifyListeners();
  }
}

/// Reproduce lo que hace AuthProvider con los providers registrados, sin
/// arrastrar la red ni el almacenamiento seguro a una prueba unitaria.
class _SesionFalsa {
  final List<SessionScoped> _registrados = [];

  void registerSessionScoped(Iterable<SessionScoped> providers) {
    _registrados
      ..clear()
      ..addAll(providers);
  }

  void vaciar() {
    for (final p in _registrados) {
      p.clearSession();
    }
  }
}

void main() {
  late _ProviderFalso camaras;
  late _ProviderFalso eventos;
  late _SesionFalsa sesion;

  setUp(() {
    camaras = _ProviderFalso();
    eventos = _ProviderFalso();
    sesion = _SesionFalsa()..registerSessionScoped([camaras, eventos]);
  });

  test('cerrar sesión vacía todos los providers registrados', () {
    sesion.vaciar();

    expect(camaras.datos, isEmpty);
    expect(eventos.datos, isEmpty);
  });

  test('el vaciado avisa a los oyentes para que la pantalla se redibuje', () {
    // Sin notifyListeners la pestaña de cámara seguiría pintando el video de
    // la cuenta anterior hasta que algo forzara una recarga: ese era el fallo.
    var avisos = 0;
    camaras.addListener(() => avisos++);

    sesion.vaciar();

    expect(avisos, 1);
  });

  test('entrar con otra cuenta vuelve a vaciar, no se acumula estado', () {
    sesion.vaciar(); // cierre de sesión
    camaras.datos = ['camara-de-la-cuenta-nueva'];
    sesion.vaciar(); // inicio de sesión de la siguiente cuenta

    expect(camaras.vaciados, 2);
    expect(camaras.datos, isEmpty);
  });

  test('registrar de nuevo reemplaza la lista en vez de duplicarla', () {
    // registerSessionScoped se llama una vez al arrancar, pero si por un
    // rearranque en caliente se llamara dos veces, no debe vaciar por
    // duplicado ni conservar providers ya desechados.
    sesion.registerSessionScoped([camaras]);
    sesion.vaciar();

    expect(camaras.vaciados, 1);
    expect(eventos.vaciados, 0);
  });
}
