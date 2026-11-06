import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/services/cupo_servidor.dart';
import '../../data/services/estado_transmision.dart';
import '../../data/services/mobile_camera_publisher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';
import '../../widgets/vs_cargando.dart';
import '../camera/aviso_sin_transmision.dart';
import '../camera/device_camera_screen.dart';
import 'elegir_camara_screen.dart';

/// «Mis cámaras» (rediseño 1.1.0). Cada cámara es una fila limpia con su
/// estado en una sola línea; los ajustes (activar o desactivar, avisos, zonas,
/// editar y eliminar) se abren en una hoja al tocarla. La pantalla anterior
/// sigue en cameras_list_screen.dart por si hay que volver.
class MisCamarasScreen extends StatefulWidget {
  const MisCamarasScreen({super.key});

  @override
  State<MisCamarasScreen> createState() => _MisCamarasScreenState();
}

class _MisCamarasScreenState extends State<MisCamarasScreen> {
  BloqueosCuenta _bloqueos = const BloqueosCuenta();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recargar());
  }

  Future<void> _recargar() async {
    final api = context.read<ApiClient>();
    final camaras = context.read<CameraProvider>();
    final results = await Future.wait([
      camaras.fetchCameras(),
      CupoServidor.bloqueos(api),
    ]);
    final b = results[1] as BloqueosCuenta?;
    if (mounted && b != null) setState(() => _bloqueos = b);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final isPrimary = context.watch<AuthProvider>().user?.isPrimary ?? false;
    final t = context.l10n;
    final camaras = provider.misCamaras;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.mcTitulo,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (isPrimary && !_bloqueos.todo)
            IconButton(
              tooltip: t.mcAgregar,
              onPressed: () => context.push(ElegirCamaraScreen.ruta),
              icon: Icon(Icons.add_rounded, color: AppColors.accent),
            ),
        ],
      ),
      body: provider.isLoading && camaras.isEmpty
          ? Center(child: VsCargando(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: _recargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_bloqueos.todo) ...[
                    _AvisoAdministrador(texto: t.mcCuentaBloqueada, contacto: _bloqueos.contacto),
                    const SizedBox(height: 16),
                  ],
                  if (camaras.isEmpty)
                    _Vacio(isPrimary: isPrimary && !_bloqueos.todo)
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(t.mcConteo(camaras.length),
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.3)),
                    ),
                    for (final cam in camaras) ...[
                      _FilaCamara(
                        cam: cam,
                        isPrimary: isPrimary,
                        bloqueada: _bloqueos.bloqueada(cam.id),
                        onTap: isPrimary
                            ? () => _abrirAjustes(context, cam.id)
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  void _abrirAjustes(BuildContext context, String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AjustesCamara(
        camaraId: id,
        bloqueos: _bloqueos,
        onEditar: (cam) => cam.isMobileWebRtc ? _abrirTelefono(context, cam) : context.push('/settings/cameras/${cam.id}'),
        onZonas: (cam) => context.push('/settings/cameras/${cam.id}/zones'),
        onEliminar: (cam) => _confirmarEliminar(context, cam),
      ),
    );
  }

  Future<void> _abrirTelefono(BuildContext context, CameraConfigModel camera) async {
    final transmitiendo = await Navigator.of(context)
        .push(MaterialPageRoute<bool>(builder: (_) => DeviceCameraScreen(camera: camera)));
    if (transmitiendo != true || !context.mounted) return;
    final id = context.read<MobileCameraPublisher>().cameraId;
    if (id != null) await context.push('/settings/cameras/$id/zones?intro=1');
  }

  void _confirmarEliminar(BuildContext context, CameraConfigModel cam) {
    final t = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.mcEliminarTitulo,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(t.mcEliminarCuerpo(cam.name), style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.mcCancelar, style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Si es este mismo teléfono transmitiendo, se corta antes.
              final publicador = context.read<MobileCameraPublisher>();
              if (publicador.cameraId == cam.id && (publicador.isPublishing || publicador.isStarting)) {
                await publicador.stop();
              }
              if (!context.mounted) return;
              await context.read<CameraProvider>().deleteCamera(cam.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(t.mcEliminada, style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppColors.alertRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            child: Text(t.mcEliminar,
                style: GoogleFonts.inter(color: AppColors.alertRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Fila de una cámara ──────────────────────────────────────────────────────

class _FilaCamara extends StatelessWidget {
  const _FilaCamara({required this.cam, required this.isPrimary, required this.bloqueada, this.onTap});

  final CameraConfigModel cam;
  final bool isPrimary;
  final bool bloqueada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final apagada = bloqueada || !cam.isActive;
    final icono = cam.isMobileWebRtc ? Icons.smartphone_rounded : Icons.videocam_rounded;
    final colorIcono = apagada ? AppColors.textMuted : AppColors.accent;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('camera-card-${cam.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colorIcono.withAlpha(apagada ? 20 : 30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, color: colorIcono, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(cam.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: apagada ? AppColors.textSecondary : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (cam.isDefault) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
                  ],
                  if (!cam.notificationsEnabled && !apagada) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: t.mcAvisosApagados,
                      child: Icon(Icons.notifications_off_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(_tipo(t),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                _LineaEstado(cam: cam, isPrimary: isPrimary, bloqueada: bloqueada),
              ]),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  String _tipo(AppStrings t) {
    if (cam.isMobileWebRtc) return t.mcTipoTelefono;
    if (!cam.isConfigured) return t.mcSinConfigurar;
    final modo = cam.streamMode == 'RtmpRelay' ? 'Relay RTMP' : 'RTSP';
    final ip = cam.cameraIp;
    return ip == null || ip.isEmpty ? '${t.mcTipoIp} · $modo' : '${t.mcTipoIp} · $ip · $modo';
  }
}

/// Estado en una sola línea, con un punto de color.
class _LineaEstado extends StatefulWidget {
  const _LineaEstado({required this.cam, required this.isPrimary, required this.bloqueada});

  final CameraConfigModel cam;
  final bool isPrimary;
  final bool bloqueada;

  @override
  State<_LineaEstado> createState() => _LineaEstadoState();
}

class _LineaEstadoState extends State<_LineaEstado> {
  bool? _enVivo;
  bool _arrancando = false;
  Timer? _timer;

  bool get _vigila => widget.cam.isMobileWebRtc && widget.cam.isActive && !widget.bloqueada;

  @override
  void initState() {
    super.initState();
    _reprogramar();
  }

  @override
  void didUpdateWidget(_LineaEstado old) {
    super.didUpdateWidget(old);
    _reprogramar();
  }

  void _reprogramar() {
    if (_vigila && _timer == null && context.read<EstadoTransmision?>() != null) {
      _consultar();
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => _consultar());
    } else if (!_vigila) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    final vivo = await context.read<EstadoTransmision?>()?.enVivo(widget.cam);
    if (mounted && vivo != _enVivo) setState(() => _enVivo = vivo);
  }

  Future<void> _transmitir() async {
    setState(() => _arrancando = true);
    final error = await transmitirDesdeEsteCelular(context, widget.cam);
    if (!mounted) return;
    setState(() => _arrancando = false);
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    unawaited(_consultar());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    if (widget.bloqueada) return _Punto(color: AppColors.alertRed, texto: t.mcBloqueadaCorta);
    if (!widget.cam.isActive) return _Punto(color: AppColors.textMuted, texto: t.mcDesactivada, hueco: true);
    if (!widget.cam.isMobileWebRtc) return _Punto(color: AppColors.safeGreen, texto: t.mcAnalizando);

    final pub = context.watch<MobileCameraPublisher?>();
    if (transmiteEsteTelefono(widget.cam, pub)) {
      return _Punto(color: AppColors.safeGreen, texto: pub!.isStarting ? t.phoneCamStarting : t.phoneCamStreaming);
    }
    return switch (_enVivo) {
      true => _Punto(color: AppColors.safeGreen, texto: t.phoneCamStreaming),
      false => Row(children: [
          Flexible(child: _Punto(color: AppColors.warningAmber, texto: t.phoneCamNotStreaming)),
          if (widget.isPrimary && pub != null) ...[
            const SizedBox(width: 8),
            InkWell(
              key: ValueKey('transmitir-${widget.cam.id}'),
              borderRadius: BorderRadius.circular(99),
              onTap: _arrancando ? null : _transmitir,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: _arrancando
                    ? SizedBox(width: 12, height: 12, child: VsCargando(color: AppColors.accent))
                    : Text(t.phoneCamStartHereShort,
                        style: GoogleFonts.inter(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      null => _Punto(color: AppColors.textMuted, texto: t.mcTipoTelefono, hueco: true),
    };
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color, required this.texto, this.hueco = false});

  final Color color;
  final String texto;
  final bool hueco;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hueco ? Colors.transparent : color,
            border: hueco ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(texto,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: hueco ? AppColors.textSecondary : color, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ]);
}

// ── Hoja de ajustes ─────────────────────────────────────────────────────────

class _AjustesCamara extends StatelessWidget {
  const _AjustesCamara({
    required this.camaraId,
    required this.bloqueos,
    required this.onEditar,
    required this.onZonas,
    required this.onEliminar,
  });

  final String camaraId;
  final BloqueosCuenta bloqueos;
  final ValueChanged<CameraConfigModel> onEditar;
  final ValueChanged<CameraConfigModel> onZonas;
  final ValueChanged<CameraConfigModel> onEliminar;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final t = context.l10n;
    final cam = provider.misCamaras.where((c) => c.id == camaraId).firstOrNull;
    if (cam == null) return const SizedBox(height: 120);
    final bloqueada = bloqueos.bloqueada(cam.id);
    final saving = provider.isSaving;

    Future<void> guardar(Future<bool> Function() accion) async {
      final ok = await accion();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? t.mcNoGuardo)));
      }
    }

    void cerrarY(ValueChanged<CameraConfigModel> f) {
      Navigator.pop(context);
      f(cam);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cam.name,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(cam.isMobileWebRtc ? t.mcTipoTelefono : t.mcTipoIp,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 20),

          if (bloqueada) ...[
            _AvisoAdministrador(texto: t.mcCamaraBloqueada, contacto: bloqueos.contacto),
            const SizedBox(height: 20),
          ] else ...[
            Text(t.mcAnalisisIa, style: _etiqueta),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(t.mcActiva), icon: const Icon(Icons.auto_awesome_rounded, size: 18)),
                  ButtonSegment(value: false, label: Text(t.mcPausada), icon: const Icon(Icons.pause_rounded, size: 18)),
                ],
                selected: {cam.isActive},
                onSelectionChanged: saving
                    ? null
                    : (s) => guardar(() => context.read<CameraProvider>().setActive(cam.id, s.first)),
                style: ButtonStyle(
                  visualDensity: VisualDensity.comfortable,
                  textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(cam.isActive ? t.mcActivaAyuda : t.mcDesactivadaAyuda,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.mcAvisos, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(t.mcAvisosAyuda, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 12),
              Switch(
                value: cam.notificationsEnabled,
                onChanged: saving
                    ? null
                    : (v) => guardar(() => context.read<CameraProvider>().setNotificationsEnabled(cam.id, v)),
              ),
            ]),
            const SizedBox(height: 24),
          ],

          Row(children: [
            Expanded(child: _Accion(icono: Icons.highlight_alt_rounded, texto: t.mcZonas, onTap: () => cerrarY(onZonas))),
            const SizedBox(width: 10),
            Expanded(child: _Accion(icono: Icons.tune_rounded, texto: t.mcEditar, onTap: () => cerrarY(onEditar))),
            const SizedBox(width: 10),
            Expanded(
              child: _Accion(
                icono: Icons.delete_forever_rounded,
                texto: t.mcEliminar,
                color: AppColors.alertRed,
                onTap: () => cerrarY(onEliminar),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  TextStyle get _etiqueta =>
      GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6);
}

class _Accion extends StatelessWidget {
  const _Accion({required this.icono, required this.texto, required this.onTap, this.color});

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Material(
      color: (color ?? AppColors.textPrimary).withAlpha(14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(children: [
            Icon(icono, color: c, size: 24),
            const SizedBox(height: 8),
            Text(texto,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: c, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _AvisoAdministrador extends StatelessWidget {
  const _AvisoAdministrador({required this.texto, this.contacto});

  final String texto;
  final String? contacto;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.alertRed.withAlpha(22),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.block_rounded, color: AppColors.alertRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contacto == null || contacto!.isEmpty ? texto : '$texto ($contacto)',
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12.5, height: 1.4),
            ),
          ),
        ]),
      );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.isPrimary});

  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(children: [
        Icon(Icons.videocam_off_rounded, color: AppColors.textMuted, size: 52),
        const SizedBox(height: 18),
        Text(t.mcSinCamaras,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(isPrimary ? t.mcSinCamarasPrincipal : t.mcSinCamarasMiembro,
            textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        if (isPrimary) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push(ElegirCamaraScreen.ruta),
            icon: const Icon(Icons.add_rounded),
            label: Text(t.mcAgregarCamara),
          ),
        ],
      ]),
    );
  }
}

extension MisCamarasStrings on AppStrings {
  String get mcTitulo => en ? 'My cameras' : 'Mis cámaras';
  String get mcAgregar => en ? 'Add' : 'Agregar';
  String get mcAgregarCamara => en ? 'Add camera' : 'Agregar cámara';
  String mcConteo(int n) => en ? (n == 1 ? '1 CAMERA' : '$n CAMERAS') : (n == 1 ? '1 CÁMARA' : '$n CÁMARAS');
  String get mcTipoTelefono => en ? 'This phone\'s camera' : 'Cámara de un teléfono';
  String get mcTipoIp => en ? 'IP camera' : 'Cámara IP';
  String get mcSinConfigurar => en ? 'IP camera · not configured' : 'Cámara IP · sin configurar';
  String get mcAnalizando => en ? 'Analyzed by AI' : 'Analizándose con IA';
  String get mcDesactivada => en ? 'Disabled: not processed by AI' : 'Desactivada: no se procesa con IA';
  String get mcBloqueadaCorta => en ? 'Disabled by the administrator' : 'Deshabilitada por el administrador';
  String get mcAvisosApagados => en ? 'Notifications off' : 'Avisos apagados';
  String get mcAnalisisIa => en ? 'AI ANALYSIS' : 'ANÁLISIS CON IA';
  String get mcActiva => en ? 'Active' : 'Activa';
  String get mcPausada => en ? 'Disabled' : 'Desactivada';
  String get mcActivaAyuda => en
      ? 'The AI analyzes the video and generates alerts.'
      : 'La IA analiza el video y genera alertas.';
  String get mcDesactivadaAyuda => en
      ? 'Disabled: not processed by AI. You can still watch the live video.'
      : 'Desactivada: no se procesa con IA. Puedes seguir viendo el video en vivo.';
  String get mcAvisos => en ? 'Notifications' : 'Avisos';
  String get mcAvisosAyuda => en
      ? 'Push notifications and WhatsApp for this camera. Events are still saved in the history.'
      : 'Notificaciones push y WhatsApp de esta cámara. Los eventos se siguen guardando en el historial.';
  String get mcZonas => en ? 'Zones' : 'Zonas';
  String get mcEditar => en ? 'Edit' : 'Editar';
  String get mcEliminar => en ? 'Delete' : 'Eliminar';
  String get mcCancelar => en ? 'Cancel' : 'Cancelar';
  String get mcEliminarTitulo => en ? 'Delete camera' : 'Eliminar cámara';
  String mcEliminarCuerpo(String n) =>
      en ? 'Delete "$n"? All its settings will be lost.' : '¿Eliminar «$n»? Se perderá toda su configuración.';
  String get mcEliminada => en ? 'Camera deleted' : 'Cámara eliminada';
  String get mcNoGuardo => en ? 'The change could not be saved.' : 'No se pudo guardar el cambio.';
  String get mcSinCamaras => en ? 'No cameras' : 'Sin cámaras';
  String get mcSinCamarasPrincipal => en
      ? 'Add an IP camera or use this phone to monitor.'
      : 'Agrega una cámara IP o usa este teléfono para monitorear.';
  String get mcSinCamarasMiembro =>
      en ? 'The main resident has not set up any cameras yet.' : 'El residente principal aún no ha configurado cámaras.';
  String get mcCamaraBloqueada => en
      ? 'This camera was disabled by the administrator and cannot be turned back on from the app. Please contact the VigiShield team for more information.'
      : 'Esta cámara fue deshabilitada por el administrador y no se puede reactivar desde la app. Comunícate con el equipo de VigiShield para más información.';
  String get mcCuentaBloqueada => en
      ? 'The cameras on this account were disabled by the administrator. Please contact the VigiShield team for more information.'
      : 'Las cámaras de esta cuenta fueron deshabilitadas por el administrador. Comunícate con el equipo de VigiShield para más información.';
}
