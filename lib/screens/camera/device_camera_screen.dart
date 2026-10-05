import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/mobile_camera_publisher.dart';
import '../../providers/camera_provider.dart';

class DeviceCameraScreen extends StatefulWidget {
  final CameraConfigModel? camera;
  final MobileCameraPublisher? publisher;
  const DeviceCameraScreen({super.key, this.camera, this.publisher});
  @override State<DeviceCameraScreen> createState() => _DeviceCameraScreenState();
}

class _DeviceCameraScreenState extends State<DeviceCameraScreen> with WidgetsBindingObserver {
  final _name = TextEditingController(text: 'Cámara del dispositivo');
  MobileCameraPublisher? _publisher;
  RTCVideoRenderer? _renderer;
  CameraConfigModel? _camera;
  bool _front = false, _busy = false, _foreground = true;
  /// Cierto si el publicador lo creo esta pantalla (solo en pruebas).
  bool _propio = false;
  String? _error;
  /// La linterna solo existe en la cámara trasera y no en todos los equipos.
  bool _linternaDisponible = false, _linterna = false;


  /// Pregunta al equipo si tiene linterna. Se consulta tras abrir la cámara
  /// porque depende de la lente escogida.
  Future<void> _revisarLinterna() async {
    final disponible = _publisher?.hasTorch ?? false;
    if (!mounted || disponible == _linternaDisponible) return;
    setState(() {
      _linternaDisponible = disponible;
      _linterna = disponible && (_publisher?.torchEnabled ?? false);
    });
  }

  Future<void> _cambiarLinterna() async {
    final valor = !_linterna;
    try {
      await _publisher?.setTorch(valor);
      if (mounted) setState(() => _linterna = valor);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo encender la linterna: $e');
    }
  }

  /// Guarda el nombre de una cámara ya creada. Renombrar no toca la clave de
  /// transmisión, así que puede hacerse en caliente sin cortar el video.
  Future<void> _guardarNombre() async {
    final camara = _camera;
    final nombre = _name.text.trim();
    if (camara == null || nombre.isEmpty || nombre == camara.name) return;
    setState(() => _busy = true);
    final cameras = context.read<CameraProvider>();
    final ok = await cameras.updateCamera(camara.id,
        SaveCameraRequest(name: nombre, streamMode: 'MobileWebRtc'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        // El provider ya guarda el modelo actualizado; se relee de ahí en vez
        // de reconstruirlo a mano.
        final i = cameras.cameras.indexWhere((c) => c.id == camara.id);
        if (i >= 0) _camera = cameras.cameras[i];
        _error = null;
      } else {
        _error = cameras.error ?? 'No se pudo guardar el nombre.';
      }
    });
  }

  @override void initState() {
    super.initState();
    _camera = widget.camera;
    if (_camera != null) _name.text = _camera!.name;
    // Si no se inyecta uno (los tests lo hacen), se usa el de la app: asi la
    // transmision sigue viva al salir de esta pantalla.
    _propio = widget.publisher != null;
    _publisher = widget.publisher ?? context.read<MobileCameraPublisher>();
    _front = _publisher?.front ?? false;
    _linternaDisponible = _publisher?.hasTorch ?? false;
    _linterna = _publisher?.torchEnabled ?? false;
    _publisher?.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePreview());
  }

  Future<void> _restorePreview() async {
    if (!mounted || _publisher?.stream == null || _renderer != null) return;
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    if (!mounted) { await renderer.dispose(); return; }
    renderer.srcObject = _publisher!.stream;
    setState(() => _renderer = renderer);
  }

  void _changed() {
    if (!mounted) return;
    _renderer?.srcObject = _publisher?.stream;
    setState(() {});
    // La linterna depende de la lente abierta, así que se revisa cada vez que
    // cambia el stream y no una sola vez al entrar.
    unawaited(_revisarLinterna());
  }

  /// Sube cada vez que la app pasa a segundo plano. Un arranque que quedó a
  /// medias se abandona aunque el usuario vuelva: comprobar sólo `_foreground`
  /// no bastaba, porque `resumed` lo devolvía a true y la cámara acababa
  /// abriéndose después de que el usuario se marchara.
  int _arranque = 0;

  Future<void> _start() async {
    if (_busy || !_foreground) return;
    final epoca = _arranque;
    bool vigente() => mounted && _foreground && epoca == _arranque;
    setState(() { _busy = true; _error = null; });
    try {
      final cameras = context.read<CameraProvider>();
      final service = CameraDataService(context.read<ApiClient>());
      if (_camera == null) {
        if (_name.text.trim().isEmpty) throw StateError('Escribe un nombre para la cámara.');
        _camera = await service.createCamera(SaveCameraRequest(
          name: _name.text.trim(), streamMode: 'MobileWebRtc'));
        if (!vigente()) return;
        await cameras.fetchCameras();
      }
      if (!vigente()) return;
      if (_renderer == null) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        if (!vigente()) { await renderer.dispose(); return; }
        _renderer = renderer;
      }
      if (!vigente()) return;
      await _publisher!.start(_camera!.id, front: _front);
    } catch (e) { if (mounted) _error = e.toString(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _stop() async {
    if (mounted) setState(() => _busy = true);
    await _publisher?.stop();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _switchLens(bool front) async {
    if (front == _front || _busy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cambiar lente'),
      content: const Text('Se detendrá la transmisión. Cambiar de lente invalida la calibración de las zonas de interés (ROI); vuelve a calibrarlas antes de confiar en las detecciones. Luego pulsa Iniciar transmisión.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cambiar'))],
    ));
    if (confirmed != true || !mounted) return;
    await _stop();
    if (mounted) setState(() => _front = front);
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _foreground = true; return; }
    // Camera permission dialogs may be inactive; actual background stops capture.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      _foreground = false;
      // Invalida cualquier arranque en curso: al volver no debe seguir solo.
      // Detener la transmision ya no es cosa de la pantalla: lo hace el propio
      // publicador, que sigue vivo aunque esta pantalla se desmonte.
      _arranque++;
    }
  }

  @override void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.removeObserver(this);
    _publisher?.removeListener(_changed);
    // Solo se desecha si lo creo esta pantalla. El de la app lo gestiona main.
    if (_propio) _publisher?.dispose();
    final renderer = _renderer;
    if (renderer != null) { renderer.srcObject = null; unawaited(renderer.dispose()); }
    _name.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final active = _publisher?.isPublishing ?? false;
    final error = _error ?? _publisher?.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Cámara de este dispositivo')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16),
        child: FilledButton.icon(onPressed: _busy ? null : active ? _stop : _start,
          icon: Icon(active ? Icons.stop : Icons.play_arrow),
          label: Text(active ? 'Detener transmisión' : 'Iniciar transmisión')))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Video sin audio. Mantén esta pantalla abierta y el dispositivo conectado. La transmisión se detiene al salir o pasar a segundo plano.'),
        const SizedBox(height: 16),
        // El nombre se puede cambiar también después de crearla: renombrar no
        // toca la clave de transmisión, así que no corta el video.
        TextField(
          controller: _name,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _guardarNombre(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Nombre de la cámara',
            suffixIcon: _camera != null && _name.text.trim().isNotEmpty &&
                    _name.text.trim() != _camera!.name
                ? IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Guardar nombre',
                    onPressed: _busy ? null : _guardarNombre)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(segments: const [
          ButtonSegment(value: false, label: Text('Trasera'), icon: Icon(Icons.camera_rear)),
          ButtonSegment(value: true, label: Text('Frontal'), icon: Icon(Icons.camera_front)),
        ], selected: {_front}, onSelectionChanged: _busy ? null : (values) => _switchLens(values.single)),
        if (_linternaDisponible) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _linterna,
            onChanged: _busy ? null : (_) => _cambiarLinterna(),
            secondary: Icon(_linterna ? Icons.flashlight_on : Icons.flashlight_off),
            title: const Text('Linterna'),
            subtitle: const Text('Para zonas oscuras. Consume más batería.'),
          ),
        ],
        const SizedBox(height: 16),
        AspectRatio(aspectRatio: 3 / 4, child: ColoredBox(color: Colors.black,
          child: _renderer != null && _publisher?.stream != null
            ? RTCVideoView(_renderer!, mirror: _front, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
            : const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 48)))),
        const SizedBox(height: 12),
        Text(active ? 'Transmitiendo' : _busy ? 'Preparando / deteniendo…' : 'Detenida'),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const Text('Si mueves el dispositivo o cambias la lente, vuelve a calibrar las zonas de interés (ROI).'),
        const SizedBox(height: 12),

      ]),
    );
  }
}
