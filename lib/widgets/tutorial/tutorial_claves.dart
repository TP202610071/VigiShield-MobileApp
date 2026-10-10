import 'package:flutter/widgets.dart';

/// Lo que el tutorial resalta. Cada pantalla pone la clave en su widget; si el
/// widget no está a la vista, el tutorial se salta ese paso.
class TutorialClaves {
  TutorialClaves._();

  static final estado = GlobalKey(debugLabel: 'tutorial-estado');
  static final tarjetaCamaras = GlobalKey(debugLabel: 'tutorial-tarjeta-camaras');
  static final agregarCamara = GlobalKey(debugLabel: 'tutorial-agregar-camara');
  static final navegacion = GlobalKey(debugLabel: 'tutorial-navegacion');
}
