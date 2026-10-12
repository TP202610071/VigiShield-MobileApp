import 'package:flutter/material.dart';

/// Al cambiar de pestaña, el contenido entra con un desvanecido y un
/// deslizamiento corto hacia el lado de la pestaña elegida.
///
/// No usa un AnimatedSwitcher: las pestañas viven en un IndexedStack con su
/// propio estado (el video sigue conectado, el historial no se recarga), y
/// duplicarlas durante la animación las rompería. Solo se anima la entrada de
/// la pestaña nueva.
class TransicionPestanas extends StatefulWidget {
  final int indice;
  final Widget child;

  const TransicionPestanas({super.key, required this.indice, required this.child});

  @override
  State<TransicionPestanas> createState() => _TransicionPestanasState();
}

class _TransicionPestanasState extends State<TransicionPestanas> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);
  late final Animation<double> _curva = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  double _lado = 1;

  @override
  void didUpdateWidget(covariant TransicionPestanas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.indice != widget.indice) {
      _lado = widget.indice > oldWidget.indice ? 1 : -1;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      child: widget.child,
      builder: (context, hijo) {
        final t = _curva.value;
        if (t >= 1) return hijo!;
        return Opacity(
          opacity: 0.25 + 0.75 * t,
          child: FractionalTranslation(translation: Offset(0.04 * _lado * (1 - t), 0), child: hijo),
        );
      },
    );
  }
}

/// Hace entrar a su hijo con un desvanecido y un deslizamiento hacia arriba.
///
/// [orden] retrasa la entrada para que una lista aparezca escalonada (cada
/// elemento un poco después del anterior, hasta un máximo). Solo se anima la
/// primera vez que se construye.
class Aparecer extends StatefulWidget {
  final Widget child;
  final int orden;

  const Aparecer({super.key, required this.child, this.orden = 0});

  static const _pasoMs = 45;
  static const _duracionMs = 360;
  static const _maximo = 8;

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> with SingleTickerProviderStateMixin {
  // La espera va dentro de la propia animación (un Interval) y no en un
  // temporizador aparte, para que no quede nada pendiente si se desmonta.
  late final int _esperaMs = Aparecer._pasoMs * widget.orden.clamp(0, Aparecer._maximo);
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: Duration(milliseconds: _esperaMs + Aparecer._duracionMs));
  late final Animation<double> _curva = CurvedAnimation(
    parent: _ctrl,
    curve: Interval(_esperaMs / (_esperaMs + Aparecer._duracionMs), 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      child: widget.child,
      builder: (context, hijo) {
        final t = _curva.value;
        if (t >= 1) return hijo!;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: hijo),
        );
      },
    );
  }
}
