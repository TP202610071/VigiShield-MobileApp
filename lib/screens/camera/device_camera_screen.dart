import 'dart:async';
import 'package:flutter/material.dart';
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
  String? _error;

  @override void initState() {
    super.initState();
    _camera = widget.camera;
    if (_camera != null) _name.text = _camera!.name;
    _publisher = widget.publisher;
    _publisher?.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    if (!mounted) return;
    _renderer?.srcObject = _publisher?.stream;
    setState(() {});
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
      _publisher ??= MobileCameraPublisher(transport: service)..addListener(_changed);
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
      _arranque++;
      unawaited(_stop());
    }
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _publisher?.removeListener(_changed);
    _publisher?.dispose();
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
        TextField(controller: _name, enabled: _camera == null && !_busy,
          decoration: const InputDecoration(labelText: 'Nombre de la cámara')),
        const SizedBox(height: 16),
        SegmentedButton<bool>(segments: const [
          ButtonSegment(value: false, label: Text('Trasera'), icon: Icon(Icons.camera_rear)),
          ButtonSegment(value: true, label: Text('Frontal'), icon: Icon(Icons.camera_front)),
        ], selected: {_front}, onSelectionChanged: _busy ? null : (values) => _switchLens(values.single)),
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
