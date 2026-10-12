import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';
import 'tutorial_guiado.dart';

/// Lo que resalta el tutorial de la primera cámara.
class TutorialCamaraClaves {
  TutorialCamaraClaves._();

  // Celular como cámara.
  static final nombre = GlobalKey(debugLabel: 'tutorial-camara-nombre');
  static final lente = GlobalKey(debugLabel: 'tutorial-camara-lente');
  static final iniciar = GlobalKey(debugLabel: 'tutorial-camara-iniciar');

  // Cámara IP.
  static final nombreIp = GlobalKey(debugLabel: 'tutorial-camara-nombre-ip');
  static final escanear = GlobalKey(debugLabel: 'tutorial-camara-escanear');
  static final ip = GlobalKey(debugLabel: 'tutorial-camara-ip');
}

/// Tutorial al agregar la primera cámara: el nombre, la lente y «Iniciar
/// transmisión» (o, en una cámara IP, el nombre, la búsqueda en la red y la
/// IP). Las zonas de interés se explican después, en su editor, con un
/// ejemplo animado.
///
/// Sale una sola vez por usuario, y solo si todavía no tiene cámaras propias
/// o si pidió ver el tutorial otra vez desde Ajustes.
class TutorialPrimeraCamara {
  TutorialPrimeraCamara._();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static String _clave(String usuario) => 'tutorial_camara_v1_$usuario';
  static const _visto = '1';
  static const _pendiente = 'pendiente';

  /// «Ver el tutorial» en Ajustes: vuelve a mostrarse aunque ya haya cámaras.
  static Future<void> olvidar(String usuario) async {
    try {
      await _storage.write(key: _clave(usuario), value: _pendiente);
    } catch (_) {}
  }

  /// Tutorial de la pantalla «Cámara de este dispositivo». true si se mostró.
  static Future<bool> celular(BuildContext context) {
    return _mostrarSiToca(context, (s) => [
      PasoTutorial(
        objetivo: () => _enPantalla(context, TutorialCamaraClaves.nombre),
        titulo: s.tcNombreTitulo,
        texto: s.tcNombreTexto,
      ),
      PasoTutorial(
        objetivo: () => _enPantalla(context, TutorialCamaraClaves.lente),
        titulo: s.tcLenteTitulo,
        texto: s.tcLenteTexto,
      ),
      PasoTutorial(
        objetivo: () => _enPantalla(context, TutorialCamaraClaves.iniciar),
        titulo: s.tcIniciarTitulo,
        texto: s.tcIniciarTexto,
        tocarParaSeguir: true,
      ),
    ]);
  }

  /// Tutorial de la pantalla «Agregar cámara» (cámara IP). true si se mostró.
  static Future<bool> camaraIp(BuildContext context) {
    return _mostrarSiToca(context, (s) => [
      PasoTutorial(
        objetivo: () => _enPantalla(context, TutorialCamaraClaves.nombreIp),
        titulo: s.tcNombreTitulo,
        texto: s.tcNombreTexto,
      ),
      PasoTutorial(
        objetivo: () => _enPantalla(context, TutorialCamaraClaves.escanear),
        titulo: s.tcEscanearTitulo,
        texto: s.tcEscanearTexto,
      ),
      PasoTutorial(
        objetivo: () => _enPantalla(context, TutorialCamaraClaves.ip),
        titulo: s.tcIpTitulo,
        texto: s.tcIpTexto,
      ),
    ]);
  }

  /// El rectángulo del widget solo si se ve entero: el tutorial no desplaza
  /// la pantalla, y resaltar algo fuera de la vista confunde.
  static Rect? _enPantalla(BuildContext context, GlobalKey clave) {
    final r = TutorialGuiado.rectDe(clave);
    if (r == null || !context.mounted) return null;
    final pantalla = Offset.zero & MediaQuery.of(context).size;
    return pantalla.contains(r.topLeft) && pantalla.contains(r.bottomRight - const Offset(1, 1)) ? r : null;
  }

  static Future<bool> _mostrarSiToca(
      BuildContext context, List<PasoTutorial> Function(AppStrings s) crearPasos) async {
    final usuario = context.read<AuthProvider?>()?.user?.id;
    final camaras = context.read<CameraProvider?>();
    if (usuario == null || camaras == null) return false;
    String? estado;
    try {
      estado = await _storage.read(key: _clave(usuario));
    } catch (_) {
      return false;
    }
    if (estado == _visto) return false;
    if (estado != _pendiente && camaras.misCamaras.isNotEmpty) return false;
    // Se espera a que termine la transición de la pantalla para medir bien.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!context.mounted || TutorialGuiado.abierto) return false;
    final pasos = crearPasos(context.l10n);
    if (!pasos.any((p) => p.objetivo() != null)) return false;

    final listo = Completer<void>();
    TutorialGuiado.mostrar(context, pasos, alTerminar: (_) {
      if (!listo.isCompleted) listo.complete();
    });
    try {
      await _storage.write(key: _clave(usuario), value: _visto);
    } catch (_) {}
    await listo.future;
    return true;
  }
}

extension TutorialCamaraStrings on AppStrings {
  String get tcNombreTitulo => en ? 'Give it a name' : 'Ponle un nombre';
  String get tcNombreTexto => en
      ? 'This is how you will recognize this camera in the history and in alerts, for example "Front door". '
          'You can change it any time.'
      : 'Así reconocerás esta cámara en el historial y en las alertas, por ejemplo «Puerta principal». '
          'Puedes cambiarlo cuando quieras.';
  String get tcLenteTitulo => en ? 'Choose the lens' : 'Elige la lente';
  String get tcLenteTexto => en
      ? 'The rear camera usually sees better. Leave the phone pointing at the entrance of your home.'
      : 'La trasera suele ver mejor. Deja el teléfono apuntando a la entrada de tu casa.';
  String get tcIniciarTitulo => en ? 'Start streaming' : 'Inicia la transmisión';
  String get tcIniciarTexto => en
      ? 'Tap "Start streaming". Next you will mark the areas of interest; we will show you how with an example.'
      : 'Toca «Iniciar transmisión». Después marcarás las zonas de interés: te mostraremos cómo con un ejemplo.';
  String get tcEscanearTitulo => en ? 'Find your camera' : 'Busca tu cámara';
  String get tcEscanearTexto => en
      ? 'If you are on the same Wi-Fi as the camera, VigiShield finds its IP address for you.'
      : 'Si estás en el mismo wifi que la cámara, VigiShield encuentra su dirección IP por ti.';
  String get tcIpTitulo => en ? 'Or type it in' : 'O escríbela tú';
  String get tcIpTexto => en
      ? 'The IP, user and password are in the camera\'s app or manual. When you are done, tap "Add camera" '
          'below and then you will draw the areas of interest.'
      : 'La IP, el usuario y la contraseña están en la app o el manual de la cámara. Al terminar, toca '
          '«Agregar cámara» abajo y luego dibujarás las zonas de interés.';
}
