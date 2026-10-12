import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/i18n/app_localizations.dart';

/// Ejemplo animado de cómo se dibuja una zona de interés, sobre la foto de una
/// entrada (stock, ver `assets/tutorial/FUENTE.txt`): un dedo toca las
/// esquinas de la puerta una a una, la zona se cierra, se rellena y recibe su
/// tipo. Se repite sola.
class DemoZonas extends StatefulWidget {
  final double ancho;
  const DemoZonas({super.key, this.ancho = 300});

  static const imagen = 'assets/tutorial/entrada_ejemplo.jpg';

  /// Esquinas de la zona en la foto (0..1): la puerta y el piso de delante.
  static const puntos = [
    Offset(0.235, 0.13),
    Offset(0.468, 0.13),
    Offset(0.468, 0.77),
    Offset(0.60, 0.89),
    Offset(0.21, 0.89),
  ];

  @override
  State<DemoZonas> createState() => _DemoZonasState();
}

/// Línea de tiempo del ejemplo, en segundos.
class _Tiempos {
  static const inicio = 0.6;
  static const porPunto = 0.75;
  static const viaje = 0.45; // lo que tarda el dedo en llegar a la esquina
  static double toque(int i) => inicio + i * porPunto + viaje;
  static final cierre = toque(DemoZonas.puntos.length - 1) + 0.55;
  static final relleno = cierre + 0.45;
  static final tipo = relleno + 0.45;
  static final finalizado = tipo + 2.2;
  static final total = finalizado + 0.6;
}

class _DemoZonasState extends State<DemoZonas> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_Tiempos.total * 1000).round()),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return SizedBox(
      width: widget.ancho,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value * _Tiempos.total;
              final paso = t < _Tiempos.cierre
                  ? s.demoZonasPaso1
                  : t < _Tiempos.tipo
                      ? s.demoZonasPaso2
                      : s.demoZonasPaso3;
              return Stack(fit: StackFit.expand, children: [
                Image.asset(DemoZonas.imagen, fit: BoxFit.cover),
                CustomPaint(painter: _ZonaPainter(t, s.demoZonasTipo)),
                Positioned(
                  left: 8,
                  top: 8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _Etiqueta(key: ValueKey(paso), texto: paso),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta({super.key, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(8)),
        child: Text(texto,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _ZonaPainter extends CustomPainter {
  final double t;
  final String nombre;
  _ZonaPainter(this.t, this.nombre);

  static const _trazo = Color(0xFF00C2FF);
  static const _puerta = Color(0xFF34D399); // el color de «Puerta» en el editor

  double _avance(double desde, double dura) => ((t - desde) / dura).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final p in DemoZonas.puntos) Offset(p.dx * size.width, p.dy * size.height)];
    // Al final todo se desvanece antes de volver a empezar.
    final opacidad = 1 - _avance(_Tiempos.finalizado, 0.5);
    if (opacidad <= 0) return;
    canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: opacidad));

    final cerrada = _avance(_Tiempos.cierre, 0.4);
    final relleno = _avance(_Tiempos.relleno, 0.4);
    final color = Color.lerp(_trazo, _puerta, relleno)!;

    // Relleno de la zona una vez cerrada.
    if (relleno > 0) {
      canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = _puerta.withValues(alpha: 0.30 * relleno));
    }

    // Lados: cada uno crece desde la esquina anterior hasta la nueva.
    final linea = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < pts.length; i++) {
      final a = _avance(_Tiempos.toque(i) - 0.30, 0.30);
      if (a > 0) canvas.drawLine(pts[i - 1], Offset.lerp(pts[i - 1], pts[i], a)!, linea);
    }
    if (cerrada > 0) canvas.drawLine(pts.last, Offset.lerp(pts.last, pts.first, cerrada)!, linea);

    // Esquinas: aparecen con un pequeño rebote y una onda al tocarlas.
    for (var i = 0; i < pts.length; i++) {
      final tocado = t - _Tiempos.toque(i);
      if (tocado < 0) continue;
      final rebote = Curves.easeOutBack.transform((tocado / 0.25).clamp(0.0, 1.0));
      if (tocado < 0.5) {
        final onda = tocado / 0.5;
        canvas.drawCircle(
            pts[i],
            6 + 16 * onda,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: 0.8 * (1 - onda)));
      }
      canvas.drawCircle(pts[i], 6.5 * rebote, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], 4.5 * rebote, Paint()..color = color);
    }

    // Tipo de la zona, en el centro de la puerta.
    final tipo = _avance(_Tiempos.tipo, 0.3);
    if (tipo > 0) _etiquetaPuerta(canvas, Offset.lerp(pts[0], pts[2], 0.5)!, tipo);

    _dedo(canvas, pts);
    canvas.restore();
  }

  /// El dedo: viaja a cada esquina y la toca.
  void _dedo(Canvas canvas, List<Offset> pts) {
    Offset? pos;
    var presion = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final llega = _Tiempos.toque(i);
      final sale = llega - _Tiempos.viaje;
      if (t >= sale && t < llega) {
        final desde = i == 0 ? pts[0] + const Offset(40, 40) : pts[i - 1];
        pos = Offset.lerp(desde, pts[i], Curves.easeInOut.transform((t - sale) / _Tiempos.viaje));
      } else if (t >= llega && t < llega + (_Tiempos.porPunto - _Tiempos.viaje)) {
        pos = pts[i];
        presion = 1 - ((t - llega) / 0.2).clamp(0.0, 1.0);
      }
    }
    // Último toque: cerrar la zona tocando la primera esquina.
    final volver = _Tiempos.cierre - _Tiempos.viaje;
    if (t >= volver && t < _Tiempos.cierre + 0.3) {
      pos = Offset.lerp(pts.last, pts.first, Curves.easeInOut.transform(((t - volver) / _Tiempos.viaje).clamp(0.0, 1.0)));
      if (t >= _Tiempos.cierre) presion = 1 - ((t - _Tiempos.cierre) / 0.2).clamp(0.0, 1.0);
    }
    if (pos == null) return;
    final r = 11 - 3 * presion;
    final p = pos + const Offset(9, 12); // la yema queda un poco abajo a la derecha
    canvas.drawCircle(p, r + 3, Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(p, r, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.black.withValues(alpha: 0.25));
  }

  void _etiquetaPuerta(Canvas canvas, Offset centro, double a) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 12, fontWeight: FontWeight.w700))
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText(nombre);
    final p = pb.build()..layout(const ui.ParagraphConstraints(width: 200));
    final ancho = p.longestLine + 16;
    final caja = Rect.fromCenter(center: centro, width: ancho, height: 22);
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    final escala = Curves.easeOutBack.transform(a);
    canvas.scale(math.max(0.01, escala));
    canvas.translate(-centro.dx, -centro.dy);
    canvas.drawRRect(RRect.fromRectAndRadius(caja, const Radius.circular(11)), Paint()..color = _puerta);
    canvas.drawParagraph(p, Offset(caja.left + 8, caja.top + (22 - p.height) / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ZonaPainter old) => old.t != t || old.nombre != nombre;
}

extension DemoZonasStrings on AppStrings {
  String get demoZonasPaso1 => en ? '1. Tap the corners' : '1. Toca las esquinas';
  String get demoZonasPaso2 => en ? '2. Close the zone' : '2. Cierra la zona';
  String get demoZonasPaso3 => en ? '3. Choose its type' : '3. Elige su tipo';
  String get demoZonasTipo => en ? 'Door' : 'Puerta';
}
