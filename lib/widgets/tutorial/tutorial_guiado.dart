import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Un paso del tutorial: qué se resalta y qué se explica.
class PasoTutorial {
  /// Rectángulo (en coordenadas de pantalla) de lo que se resalta, o null si
  /// no está a la vista (el paso se salta).
  final Rect? Function() objetivo;
  final String titulo;
  final String texto;

  /// El último paso puede pedir que se toque DE VERDAD lo resaltado (por
  /// ejemplo «Agregar cámara»): el toque pasa a la app y el tutorial termina.
  final bool tocarParaSeguir;

  const PasoTutorial({
    required this.objetivo,
    required this.titulo,
    required this.texto,
    this.tocarParaSeguir = false,
  });
}

/// Tutorial guiado: oscurece la pantalla salvo lo que hay que mirar o tocar,
/// con una tarjeta que lo explica, «Siguiente» y «Saltar tutorial» (que antes
/// pide confirmación y recomienda seguirlo). Se muestra una vez por usuario.
class TutorialGuiado {
  TutorialGuiado._();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static String _clave(String usuario) => 'tutorial_inicio_v1_$usuario';

  /// Ajustes → «Ver el tutorial» lo vuelve a pedir; el inicio lo escucha.
  static final pedido = ValueNotifier<int>(0);
  static bool _abierto = false;

  /// Si hay un tutorial a la vista (no se abren dos a la vez).
  static bool get abierto => _abierto;

  static Future<bool> visto(String usuario) async {
    try {
      return await _storage.read(key: _clave(usuario)) == '1';
    } catch (_) {
      return true; // sin almacenamiento, mejor no insistir en cada arranque
    }
  }

  static Future<void> marcarVisto(String usuario) async {
    try {
      await _storage.write(key: _clave(usuario), value: '1');
    } catch (_) {}
  }

  static Future<void> olvidar(String usuario) async {
    try {
      await _storage.delete(key: _clave(usuario));
    } catch (_) {}
  }

  /// Rectángulo en pantalla del widget con esa clave (o null si no se ve).
  static Rect? rectDe(GlobalKey clave) {
    final box = clave.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Rectángulo de la pestaña `i` de una barra de `total` pestañas iguales y
  /// `alto` px (la barra puede tener debajo el margen del sistema).
  static Rect? rectPestana(GlobalKey barra, int i, int total, {double alto = 64}) {
    final r = rectDe(barra);
    if (r == null) return null;
    final ancho = r.width / total;
    return Rect.fromLTWH(r.left + ancho * i, r.top, ancho, alto);
  }

  /// Muestra los pasos. `alTerminar(completo)` se llama al terminar o saltar.
  static void mostrar(BuildContext context, List<PasoTutorial> pasos,
      {required void Function(bool completo) alTerminar}) {
    final visibles = pasos.where((p) => p.objetivo() != null).toList();
    if (visibles.isEmpty || _abierto) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entrada;
    _abierto = true;
    entrada = OverlayEntry(
      builder: (_) => _TutorialOverlay(
        pasos: visibles,
        alCerrar: (completo) {
          entrada.remove();
          _abierto = false;
          alTerminar(completo);
        },
      ),
    );
    overlay.insert(entrada);
  }
}

class _TutorialOverlay extends StatefulWidget {
  final List<PasoTutorial> pasos;
  final void Function(bool completo) alCerrar;
  const _TutorialOverlay({required this.pasos, required this.alCerrar});

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> with WidgetsBindingObserver {
  int _i = 0;
  Rect? _hueco;
  bool _cerrado = false;

  PasoTutorial get _paso => widget.pasos[_i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _medir();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => WidgetsBinding.instance.addPostFrameCallback((_) => _medir());

  void _medir() {
    if (!mounted) return;
    setState(() => _hueco = _paso.objetivo()?.inflate(6));
  }

  void _cerrar(bool completo) {
    if (_cerrado) return;
    _cerrado = true;
    widget.alCerrar(completo);
  }

  void _siguiente() {
    // Salta los pasos cuyo objetivo ya no está a la vista.
    var j = _i + 1;
    while (j < widget.pasos.length && widget.pasos[j].objetivo() == null) {
      j++;
    }
    if (j >= widget.pasos.length) {
      _cerrar(true);
      return;
    }
    _i = j;
    _medir();
  }

  // La confirmación de "saltar" se dibuja dentro del propio tutorial: un
  // diálogo normal quedaría DEBAJO de esta capa (las rutas nuevas se insertan
  // bajo las entradas agregadas a mano) y no se podría tocar.
  bool _confirmandoSalto = false;

  void _saltar() => setState(() => _confirmandoSalto = true);

  void _alTocarHueco() {
    if (_paso.tocarParaSeguir) {
      // El toque ya le llega a la app (p. ej. abre «Agregar cámara").
      scheduleMicrotask(() => _cerrar(true));
    } else {
      _siguiente();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final pantalla = MediaQuery.of(context).size;
    final hueco = _hueco;
    final abajo = hueco == null || hueco.center.dy < pantalla.height * 0.55;
    final ultimo = _i == widget.pasos.length - 1;

    final tarjeta = Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(18),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(_paso.titulo,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            Text('${_i + 1}/${widget.pasos.length}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 8),
          Text(_paso.texto,
              style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            TextButton(
              onPressed: _saltar,
              child: Text(s.tutorialSaltar, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
            ),
            const Spacer(),
            if (_paso.tocarParaSeguir)
              Text(s.tutorialTocaResaltado,
                  style: GoogleFonts.inter(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600))
            else
              ElevatedButton(
                onPressed: _siguiente,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(ultimo ? s.tutorialEntendido : s.tutorialSiguiente,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
          ]),
        ]),
      ),
    );

    if (_confirmandoSalto) {
      return Stack(children: [
        const Positioned.fill(child: ModalBarrier(color: Color(0xE6000000), dismissible: false)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.tutorialSaltarTitulo,
                      style: GoogleFonts.inter(
                          fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Text(s.tutorialSaltarTexto,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => _cerrar(false),
                      child: Text(s.tutorialSaltar, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _confirmandoSalto = false),
                      child: Text(s.tutorialSeguir,
                          style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]);
    }

    return Stack(children: [
      Positioned.fill(
        child: _Barrera(
          hueco: hueco,
          pasar: _paso.tocarParaSeguir,
          alTocarHueco: _alTocarHueco,
          child: CustomPaint(painter: _Oscuro(hueco)),
        ),
      ),
      if (hueco != null)
        Positioned(
          left: 16,
          right: 16,
          top: abajo ? hueco.bottom + 14 : null,
          bottom: abajo ? null : pantalla.height - hueco.top + 14,
          child: SafeArea(top: abajo, bottom: !abajo, child: tarjeta),
        ),
    ]);
  }
}

/// Todo oscuro salvo el hueco, con un borde del color de la app.
class _Oscuro extends CustomPainter {
  final Rect? hueco;
  _Oscuro(this.hueco);

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Offset.zero & size);
    final h = hueco;
    if (h == null) {
      canvas.drawPath(fondo, Paint()..color = const Color(0xD9000000));
      return;
    }
    final rr = RRect.fromRectAndRadius(h, const Radius.circular(14));
    canvas.drawPath(Path.combine(PathOperation.difference, fondo, Path()..addRRect(rr)),
        Paint()..color = const Color(0xD9000000));
    canvas.drawRRect(rr, Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_Oscuro old) => old.hueco != hueco;
}

/// Bloquea los toques fuera del hueco. Dentro del hueco, o los deja pasar a
/// la app (paso que pide tocar de verdad) o los usa para avanzar.
class _Barrera extends SingleChildRenderObjectWidget {
  final Rect? hueco;
  final bool pasar;
  final VoidCallback alTocarHueco;
  const _Barrera({required this.hueco, required this.pasar, required this.alTocarHueco, super.child});

  @override
  _RenderBarrera createRenderObject(BuildContext context) => _RenderBarrera(hueco, pasar, alTocarHueco);

  @override
  void updateRenderObject(BuildContext context, _RenderBarrera r) {
    r
      ..hueco = hueco
      ..pasar = pasar
      ..alTocarHueco = alTocarHueco;
  }
}

class _RenderBarrera extends RenderProxyBox {
  Rect? hueco;
  bool pasar;
  VoidCallback alTocarHueco;
  _RenderBarrera(this.hueco, this.pasar, this.alTocarHueco);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    // Dentro del hueco y "pasar": se observa el toque pero NO se lo queda, así
    // el widget de abajo también lo recibe.
    final enHueco = hueco?.contains(position) ?? false;
    return !(enHueco && pasar);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerUpEvent && (hueco?.contains(event.localPosition) ?? false)) {
      alTocarHueco();
    }
  }
}

extension TutorialStrings on AppStrings {
  String get tutorialSiguiente => en ? 'Next' : 'Siguiente';
  String get tutorialEntendido => en ? 'Got it' : 'Entendido';
  String get tutorialSaltar => en ? 'Skip tutorial' : 'Saltar tutorial';
  String get tutorialSeguir => en ? 'Continue tutorial' : 'Seguir el tutorial';
  String get tutorialSaltarTitulo => en ? 'Skip the tutorial?' : '¿Saltar el tutorial?';
  String get tutorialSaltarTexto => en
      ? 'We recommend following it: it takes less than a minute and shows you how to start watching '
          'your home. You can see it again from Settings.'
      : 'Te recomendamos seguirlo: toma menos de un minuto y te enseña cómo empezar a vigilar tu casa. '
          'Puedes volver a verlo desde Ajustes.';
  String get tutorialTocaResaltado => en ? 'Tap the highlighted button' : 'Toca el botón resaltado';
  String get tutorialVerDeNuevo => en ? 'See the tutorial' : 'Ver el tutorial';

  String get tutEstadoTitulo => en ? 'Your monitoring' : 'Tu vigilancia';
  String get tutEstadoTexto => en
      ? 'Here you see whether VigiShield is watching your home. You can pause it whenever you want.'
      : 'Aquí ves si VigiShield está vigilando tu casa. Puedes pausarlo cuando quieras.';
  String get tutCamaraTitulo => en ? 'Your first camera' : 'Tu primera cámara';
  String get tutCamaraTexto => en
      ? 'Start here: add an IP camera from your home or use this phone as a camera.'
      : 'Empieza por aquí: agrega una cámara IP de tu casa o usa este celular como cámara.';
  String get tutEjemploTitulo => en ? 'Sample video' : 'Video de ejemplo';
  String get tutEjemploTexto => en
      ? 'If nobody walks in front of your camera, play a sample video to see how VigiShield works.'
      : 'Si nadie pasa frente a tu cámara, mira un video de ejemplo para ver cómo funciona VigiShield.';
  String get tutPestanaCamaraTitulo => en ? 'Camera' : 'Cámara';
  String get tutPestanaCamaraTexto => en
      ? 'Watch your camera live or in AI mode, which marks each person and their risk level.'
      : 'Mira tu cámara en vivo o en modo IA, que marca a cada persona y su nivel de riesgo.';
  String get tutHistorialTitulo => en ? 'History' : 'Historial';
  String get tutHistorialTexto => en
      ? 'Every event is saved here with its photo, its clip and its risk level.'
      : 'Cada evento queda guardado aquí con su foto, su clip y su nivel de riesgo.';
  String get tutAjustesTitulo => en ? 'Settings' : 'Ajustes';
  String get tutAjustesTexto => en
      ? 'Register your family\'s faces, draw the zones of your entrance and choose which alerts you get.'
      : 'Registra los rostros de tu familia, dibuja las zonas de tu entrada y elige qué alertas recibir.';
  String get tutEmpezarTitulo => en ? 'Let\'s start!' : '¡Empecemos!';
  String get tutEmpezarTexto => en
      ? 'Tap «Add camera» to set up your first camera.'
      : 'Toca «Agregar cámara» para configurar tu primera cámara.';
}
