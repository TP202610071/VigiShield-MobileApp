import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';

/// «Llamada de voz» en Alerta de emergencia.
///
/// Si el número del perfil está verificado en Twilio, el servidor llama con
/// voz sintetizada ante un evento de riesgo alto, aunque el teléfono esté
/// bloqueado o la app cerrada. Si no lo está, la alerta sigue como antes.
/// Se oculta si el servidor no tiene las llamadas configuradas.
class TarjetaLlamadaVoz extends StatefulWidget {
  const TarjetaLlamadaVoz({super.key});

  @override
  State<TarjetaLlamadaVoz> createState() => _TarjetaLlamadaVozState();
}

class _TarjetaLlamadaVozState extends State<TarjetaLlamadaVoz> {
  Map<String, dynamic>? _estado;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Dio get _dio => context.read<ApiClient>().dio;

  Future<Map<String, dynamic>?> _cargar() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/api/llamadas/estado');
      if (mounted) setState(() => _estado = r.data);
      return r.data;
    } catch (_) {
      return null;
    }
  }

  String _error(Object e) {
    final t = context.l10n;
    final d = e is DioException ? e.response?.data : null;
    final msg = d is Map ? d['error']?.toString() : null;
    if (msg != null && msg.startsWith('Twilio')) return t.lvNoDisponibleBeta;
    return msg ?? t.lvError;
  }

  Future<void> _accion(Future<void> Function() f) async {
    setState(() => _ocupado = true);
    try {
      await f();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _verificar() => _accion(() async {
        final r = await _dio.post<Map<String, dynamic>>('/api/llamadas/verificar');
        final codigo = r.data?['codigo']?.toString();
        if (codigo == null || !mounted) return;
        await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _DialogoCodigo(codigo: codigo, consultar: _cargar));
        await _cargar();
      });

  Future<void> _probar() => _accion(() async {
        await _dio.post<void>('/api/llamadas/prueba');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.lvPruebaEnCamino)));
      });

  Future<void> _quitar() => _accion(() async {
        await _dio.delete<void>('/api/llamadas/verificar');
        await _cargar();
      });

  @override
  Widget build(BuildContext context) {
    final e = _estado;
    if (e == null || e['disponible'] != true) return const SizedBox.shrink();
    final t = context.l10n;
    final verificado = e['verificado'] == true;
    final tieneNumero = e['tieneNumero'] == true;
    final numero = e['numero']?.toString() ?? '';
    final color = verificado ? AppColors.safeGreen : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(verificado ? Icons.phone_in_talk_rounded : Icons.add_ic_call_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(verificado ? t.lvActiva : t.lvTitulo,
                style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          !tieneNumero ? t.lvSinNumero : verificado ? t.lvActivaCuerpo(numero) : t.lvVerificarCuerpo(numero),
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
        ),
        if (tieneNumero) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, children: [
            if (verificado) ...[
              TextButton(onPressed: _ocupado ? null : _probar, child: Text(t.lvProbar)),
              TextButton(
                onPressed: _ocupado ? null : _quitar,
                child: Text(t.lvDejar, style: TextStyle(color: AppColors.textSecondary)),
              ),
            ] else
              TextButton(onPressed: _ocupado ? null : _verificar, child: Text(t.lvVerificar)),
          ]),
        ],
      ]),
    );
  }
}

/// Muestra el código mientras Twilio llama; se cierra solo al quedar verificado.
class _DialogoCodigo extends StatefulWidget {
  const _DialogoCodigo({required this.codigo, required this.consultar});

  final String codigo;
  final Future<Map<String, dynamic>?> Function() consultar;

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  Timer? _timer;
  int _vueltas = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (++_vueltas > 45) return _timer?.cancel(); // 3 min
      final e = await widget.consultar();
      if (mounted && e?['verificado'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.lvListo)));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text(t.lvDialogoTitulo, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t.lvDialogoCuerpo, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 18),
        SelectableText(widget.codigo,
            style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 6, color: AppColors.accent)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.lvCerrar))],
    );
  }
}

extension LlamadaVozStrings on AppStrings {
  String get lvTitulo => en ? 'Voice call' : 'Llamada de voz';
  String get lvActiva => en ? 'Voice call enabled' : 'Llamada de voz activa';
  String get lvSinNumero => en
      ? 'Add your phone number in your profile to receive a call when a high-risk alert occurs.'
      : 'Agrega tu número de teléfono en tu perfil para recibir una llamada cuando haya una alerta de riesgo alto.';
  String lvActivaCuerpo(String n) => en
      ? 'We will call $n with a synthesized voice when a camera detects a high risk, even if the phone is locked.'
      : 'Te llamaremos al $n con una voz sintetizada cuando una cámara detecte un riesgo alto, aunque el teléfono esté bloqueado.';
  String lvVerificarCuerpo(String n) => en
      ? 'Receive a call at $n when a camera detects a high risk, even if the phone is locked. To enable it, you will get one call: answer it and dial the code shown here.'
      : 'Recibe una llamada al $n cuando una cámara detecte un riesgo alto, aunque el teléfono esté bloqueado. Para activarla recibirás una llamada: contéstala y marca el código que verás aquí.';
  String get lvVerificar => en ? 'Verify my number' : 'Verificar mi número';
  String get lvProbar => en ? 'Test call' : 'Probar llamada';
  String get lvDejar => en ? 'Stop calls' : 'Dejar de recibir';
  String get lvPruebaEnCamino => en ? 'You will receive the call in a few seconds.' : 'Recibirás la llamada en unos segundos.';
  String get lvDialogoTitulo => en ? 'Answer the call' : 'Contesta la llamada';
  String get lvDialogoCuerpo => en
      ? 'You will receive a call in a few seconds. Answer it and dial this code on the keypad:'
      : 'En unos segundos recibirás una llamada. Contéstala y marca este código en el teclado:';
  String get lvListo => en ? 'Number verified. Voice calls are enabled.' : 'Número verificado. La llamada de voz quedó activa.';
  String get lvCerrar => en ? 'Close' : 'Cerrar';
  String get lvError => en ? 'It could not be completed. Please try again.' : 'No se pudo completar. Inténtalo de nuevo.';
  String get lvNoDisponibleBeta => en
      ? 'Automatic verification is not available during the beta phase.'
      : 'La verificación automática no está disponible durante la fase beta.';
}
