import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_settings_provider.dart';
import 'tutorial_claves.dart';
import 'tutorial_guiado.dart';

/// Lanza el tutorial del inicio la primera vez que un usuario entra (y cuando
/// lo pide desde Ajustes). Envuelve el contenido de las pestañas.
class TutorialInicial extends StatefulWidget {
  final Widget child;

  /// Pestaña visible (0 = Inicio): el tutorial solo arranca en el inicio.
  final int Function() pestanaActual;

  const TutorialInicial({super.key, required this.child, required this.pestanaActual});

  @override
  State<TutorialInicial> createState() => _TutorialInicialState();
}

class _TutorialInicialState extends State<TutorialInicial> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    TutorialGuiado.pedido.addListener(_alPedirlo);
    _programar(const Duration(milliseconds: 1200), forzar: false, intentos: 8);
  }

  @override
  void dispose() {
    _timer?.cancel();
    TutorialGuiado.pedido.removeListener(_alPedirlo);
    super.dispose();
  }

  void _alPedirlo() => _programar(const Duration(milliseconds: 900), forzar: true, intentos: 8);

  void _programar(Duration espera, {required bool forzar, required int intentos}) {
    _timer?.cancel();
    _timer = Timer(espera, () => _intentar(forzar: forzar, intentos: intentos));
  }

  Future<void> _intentar({required bool forzar, required int intentos}) async {
    if (!mounted) return;
    // Lectura opcional: en pruebas (o si cambia el árbol) puede no haber sesión.
    final usuario = context.read<AuthProvider?>()?.user;
    if (usuario == null) return;
    if (!forzar && await TutorialGuiado.visto(usuario.id)) return;
    if (!mounted) return;
    // Solo en el inicio, sin otra pantalla encima y con la tarjeta de cámaras
    // ya dibujada (aparece cuando termina de cargar la lista).
    final listo = widget.pestanaActual() == 0 &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TutorialClaves.tarjetaCamaras.currentContext != null;
    if (!listo) {
      if (intentos > 0) _programar(const Duration(seconds: 1), forzar: forzar, intentos: intentos - 1);
      return;
    }
    final s = context.l10n;
    final principal = context.read<DevSettingsProvider?>()?.isPrimaryEffective(usuario) ?? usuario.isPrimary;
    final sinCamaras = TutorialClaves.agregarCamara.currentContext != null;
    final pasos = <PasoTutorial>[
      PasoTutorial(
          objetivo: () => TutorialGuiado.rectDe(TutorialClaves.estado),
          titulo: s.tutEstadoTitulo,
          texto: s.tutEstadoTexto),
      PasoTutorial(
          objetivo: () => TutorialGuiado.rectDe(TutorialClaves.tarjetaCamaras),
          titulo: sinCamaras ? s.tutCamaraTitulo : s.tutEjemploTitulo,
          texto: sinCamaras ? s.tutCamaraTexto : s.tutEjemploTexto),
      PasoTutorial(
          objetivo: () => TutorialGuiado.rectPestana(TutorialClaves.navegacion, 1, 4),
          titulo: s.tutPestanaCamaraTitulo,
          texto: s.tutPestanaCamaraTexto),
      PasoTutorial(
          objetivo: () => TutorialGuiado.rectPestana(TutorialClaves.navegacion, 2, 4),
          titulo: s.tutHistorialTitulo,
          texto: s.tutHistorialTexto),
      PasoTutorial(
          objetivo: () => TutorialGuiado.rectPestana(TutorialClaves.navegacion, 3, 4),
          titulo: s.tutAjustesTitulo,
          texto: s.tutAjustesTexto),
      if (principal && sinCamaras)
        PasoTutorial(
            objetivo: () => TutorialGuiado.rectDe(TutorialClaves.agregarCamara),
            titulo: s.tutEmpezarTitulo,
            texto: s.tutEmpezarTexto,
            tocarParaSeguir: true),
    ];
    TutorialGuiado.mostrar(context, pasos, alTerminar: (_) => TutorialGuiado.marcarVisto(usuario.id));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
