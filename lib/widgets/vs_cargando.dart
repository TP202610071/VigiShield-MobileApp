import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Indicador de carga de VigiShield: reemplaza al círculo giratorio de siempre.
///
/// - Grande (pantallas que cargan): una cámara de vigilancia que gira de lado
///   a lado con su haz de luz, ondas que salen del lente y la luz roja de
///   grabación parpadeando.
/// - Pequeño (dentro de un botón o una fila, menos de 32 px): un radar que
///   barre en círculo, que se lee bien aunque mida 12 px.
///
/// Sin [size], toma el tamaño de un `SizedBox` que lo envuelva; si no lo hay,
/// mide 56 px.
class VsCargando extends StatefulWidget {
  final double? size;
  final Color? color;
  final String? semanticsLabel;

  const VsCargando({super.key, this.size, this.color, this.semanticsLabel});

  static const double tamanoPorDefecto = 56;
  static const double limiteCompacto = 32;

  @override
  State<VsCargando> createState() => _VsCargandoState();
}

class _VsCargandoState extends State<VsCargando> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    return Semantics(
      label: widget.semanticsLabel,
      child: LayoutBuilder(builder: (context, c) {
        final lado = widget.size ??
            (c.hasTightWidth && c.hasTightHeight
                ? math.min(c.maxWidth, c.maxHeight)
                : VsCargando.tamanoPorDefecto);
        final compacto = lado < VsCargando.limiteCompacto;
        return SizedBox.square(
          dimension: lado,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: compacto
                  ? _RadarPainter(_ctrl, color)
                  : _CamaraPainter(_ctrl, color, AppColors.alertRed),
            ),
          ),
        );
      }),
    );
  }
}

/// Radar: aro tenue, barrido con estela y un punto que late en el centro.
class _RadarPainter extends CustomPainter {
  final Animation<double> t;
  final Color color;

  _RadarPainter(this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final grosor = math.max(1.2, s * 0.11);
    final r = s / 2 - grosor / 2;

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..color = color.withValues(alpha: 0.18));

    // Dos vueltas por ciclo: 1.2 s por vuelta.
    final angulo = t.value * 4 * math.pi;
    const estela = 1.9;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angulo);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawArc(
        rect,
        -estela,
        estela,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -estela,
            endAngle: 0,
            colors: [color.withValues(alpha: 0), color],
            tileMode: TileMode.clamp,
          ).createShader(rect));
    canvas.restore();

    final latido = 0.5 + 0.5 * math.sin(t.value * 6 * math.pi);
    canvas.drawCircle(c, s * (0.09 + 0.04 * latido), Paint()..color = color.withValues(alpha: 0.55 + 0.45 * latido));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.color != color || old.t != t;
}

/// Cámara de vigilancia que vigila de lado a lado.
class _CamaraPainter extends CustomPainter {
  final Animation<double> t;
  final Color color;
  final Color luz;

  _CamaraPainter(this.t, this.color, this.luz) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));

    final v = t.value;
    final oscuro = Color.lerp(color, Colors.black, 0.45)!;
    const pivote = Offset(0.22, 0.40);

    // Soporte en la pared y brazo hasta el pivote.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(0.04, 0.27, 0.12, 0.53), const Radius.circular(0.025)),
        Paint()..color = oscuro);
    canvas.drawLine(
        const Offset(0.11, 0.40),
        pivote,
        Paint()
          ..color = oscuro
          ..strokeWidth = 0.055
          ..strokeCap = StrokeCap.round);

    // Giro suave de lado a lado, apuntando un poco hacia abajo.
    final giro = 0.24 + 0.34 * math.sin(v * 2 * math.pi);
    canvas.translate(pivote.dx, pivote.dy);
    canvas.rotate(giro);

    // Haz de luz: se desvanece al alejarse del lente.
    const lente = Offset(0.43, 0.0);
    final haz = Path()
      ..moveTo(lente.dx, -0.05)
      ..lineTo(1.10, -0.30)
      ..lineTo(1.10, 0.30)
      ..lineTo(lente.dx, 0.05)
      ..close();
    canvas.drawPath(
        haz,
        Paint()
          ..shader = LinearGradient(
            colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0.0)],
          ).createShader(const Rect.fromLTRB(0.43, -0.3, 1.10, 0.3)));

    // Ondas que salen del lente, dentro del haz.
    for (var k = 0; k < 2; k++) {
      final f = (v * 3 + k / 2) % 1.0;
      final radio = 0.10 + f * 0.55;
      canvas.drawArc(
          Rect.fromCircle(center: lente, radius: radio),
          -0.38,
          0.76,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.025
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: 0.7 * (1 - f)));
    }

    // Visera, cuerpo y lente.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(0.03, -0.135, 0.47, -0.085), const Radius.circular(0.02)),
        Paint()..color = oscuro);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(-0.02, -0.095, 0.42, 0.095), const Radius.circular(0.05)),
        Paint()..color = color);
    canvas.drawCircle(lente, 0.075, Paint()..color = oscuro);
    canvas.drawCircle(lente, 0.045, Paint()..color = const Color(0xFF05080F));
    canvas.drawCircle(lente + const Offset(-0.015, -0.015), 0.014, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // Luz de grabación: dos destellos por ciclo.
    final encendida = (v * 2) % 1.0 < 0.55;
    if (encendida) {
      canvas.drawCircle(const Offset(0.07, -0.02), 0.045, Paint()..color = luz.withValues(alpha: 0.30));
    }
    canvas.drawCircle(const Offset(0.07, -0.02), 0.024,
        Paint()..color = encendida ? luz : Color.lerp(luz, Colors.black, 0.55)!);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CamaraPainter old) => old.color != color || old.t != t || old.luz != luz;
}
