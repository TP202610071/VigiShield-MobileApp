import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/models/security_event_model.dart';
import '../../providers/camera_provider.dart';
import '../../providers/event_provider.dart';

enum _ViewMode { single, grid }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  // ── Single-camera player ───────────────────────────────────────────────────
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;
  String? _currentUrl;

  // ── Multi-camera grid ──────────────────────────────────────────────────────
  _ViewMode _viewMode = _ViewMode.single;
  final Map<String, VideoPlayerController> _gridControllers = {};
  final Map<String, bool> _gridReady = {};

  // ── Demo simulation ────────────────────────────────────────────────────────
  bool _simulatedAlertFired = false;
  bool _showAlert = false;
  SecurityEventModel? _alertEvent;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    // Allow landscape for immersive video viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStream());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _alertTimer?.cancel();
    // Restore portrait-only when leaving camera screen
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller?.dispose();
    for (final c in _gridControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Stream initialisation ──────────────────────────────────────────────────

  Future<void> _initStream() async {
    final provider = context.read<CameraProvider>();
    if (provider.cameras.isEmpty) await provider.fetchCameras();
    if (!mounted) return;
    await _startSinglePlayer();
  }

  Future<void> _startSinglePlayer({String? overrideUrl}) async {
    final url = overrideUrl ?? context.read<CameraProvider>().hlsViewUrl;

    if (url == null || url.isEmpty) {
      setState(() { _error = 'no_config'; _initializing = false; });
      return;
    }

    setState(() { _initializing = true; _error = null; });

    if (_currentUrl != url) {
      await _controller?.dispose();
      _controller = null;
    }
    _currentUrl = url;

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = ctrl;

    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) {
        setState(() => _initializing = false);
        _scheduleSimulatedAlert();
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'stream_error'; _initializing = false; });
    }
  }

  void _scheduleSimulatedAlert() {
    if (_simulatedAlertFired) return;
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _simulatedAlertFired) return;
      _simulatedAlertFired = true;
      final event = SecurityEventModel.simulated();
      // Inject into history log
      context.read<EventProvider>().injectSimulatedEvent(event);
      // Vibrate for drama
      HapticFeedback.vibrate();
      setState(() {
        _alertEvent = event;
        _showAlert = true;
      });
    });
  }

  Future<void> _switchCamera(int index) async {
    context.read<CameraProvider>().selectCamera(index);
    final url = context.read<CameraProvider>().hlsViewUrl;
    await _startSinglePlayer(overrideUrl: url);
  }

  Future<void> _retry() async {
    await context.read<CameraProvider>().fetchCameras();
    if (!mounted) return;
    await _startSinglePlayer();
  }

  // ── Grid mode ──────────────────────────────────────────────────────────────

  Future<void> _enterGridMode() async {
    setState(() => _viewMode = _ViewMode.grid);
    final cameras = context.read<CameraProvider>().cameras;

    for (final cam in cameras) {
      final url = cam.hlsViewUrl;
      if (url == null || url.isEmpty) continue;
      if (_gridControllers.containsKey(cam.id)) continue;

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _gridControllers[cam.id] = ctrl;
      _gridReady[cam.id] = false;

      ctrl.initialize().then((_) {
        ctrl.setLooping(true);
        ctrl.play();
        if (mounted) setState(() => _gridReady[cam.id] = true);
      }).catchError((_) {
        if (mounted) setState(() => _gridReady[cam.id] = false);
      });
    }
  }

  void _exitGridMode(int cameraIndex) {
    context.read<CameraProvider>().selectCamera(cameraIndex);
    setState(() => _viewMode = _ViewMode.single);
    _startSinglePlayer();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
      for (final c in _gridControllers.values) c.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
      for (final c in _gridControllers.values) c.play();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      final isLandscape = orientation == Orientation.landscape;

      return Scaffold(
        backgroundColor: Colors.black,
        body: _viewMode == _ViewMode.grid
            ? _buildGrid(isLandscape)
            : _buildSingle(isLandscape),
      );
    });
  }

  // ── Single-camera layout ───────────────────────────────────────────────────

  Widget _buildSingle(bool isLandscape) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildSingleContent(),
        _buildTopBar(isLandscape),
        _buildBottomBar(isLandscape),
        // Demo alert overlay
        if (_showAlert && _alertEvent != null)
          _AlertBanner(
            event: _alertEvent!,
            onDismiss: () => setState(() => _showAlert = false),
          ),
      ],
    );
  }

  Widget _buildSingleContent() {
    if (_initializing) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Conectando…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      );
    }
    if (_error == 'no_config') return _buildNotConfigured();
    if (_error == 'stream_error') return _buildStreamError();

    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool isLandscape) {
    final provider = context.watch<CameraProvider>();
    final isLive = _controller?.value.isPlaying ?? false;
    final camName = provider.selectedCamera?.name;
    final hasMultiple = provider.cameras.length > 1;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: isLandscape ? 12 : MediaQuery.of(context).padding.top + 12,
          left: 16, right: 16, bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withAlpha(191), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _LiveBadge(isLive: isLive),
            const SizedBox(width: 10),
            if (camName != null)
              Expanded(
                child: Text(camName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 12,
                        fontWeight: FontWeight.w500)),
              )
            else
              const Spacer(),
            // Grid toggle (only when multiple cameras)
            if (hasMultiple) ...[
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.grid_view_rounded,
                tooltip: 'Ver todas las cámaras',
                onTap: _enterGridMode,
              ),
              const SizedBox(width: 8),
            ],
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, __) => Text(
                DateFormat('HH:mm:ss').format(DateTime.now()),
                style: GoogleFonts.robotoMono(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isLandscape) {
    final provider = context.watch<CameraProvider>();
    final cameras = provider.cameras;
    if (cameras.isEmpty || _error != null) return const SizedBox.shrink();

    final selectedIdx = cameras.indexOf(provider.selectedCamera ?? cameras.first);

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: isLandscape ? 12 : MediaQuery.of(context).padding.bottom + 12,
          top: 16, left: 14, right: 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(191), Colors.transparent],
          ),
        ),
        child: Row(children: [
          // Camera chips (only when multiple cameras)
          if (cameras.length > 1)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(cameras.length, (i) {
                    final selected = i == selectedIdx;
                    return GestureDetector(
                      onTap: () => _switchCamera(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accent
                              : Colors.white.withAlpha(46),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.videocam_outlined,
                              color: selected ? Colors.black : Colors.white70,
                              size: 13),
                          const SizedBox(width: 5),
                          Text(cameras[i].name,
                              style: GoogleFonts.inter(
                                color: selected ? Colors.black : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                        ]),
                      ),
                    );
                  }),
                ),
              ),
            )
          else
            const Spacer(),
          // Reload button
          if (!_initializing) ...[
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.refresh, onTap: _retry),
          ],
        ]),
      ),
    );
  }

  // ── Grid layout ────────────────────────────────────────────────────────────

  Widget _buildGrid(bool isLandscape) {
    final cameras = context.watch<CameraProvider>().cameras;

    return Stack(children: [
      // Grid of video players
      SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.black,
            child: Row(children: [
              const Icon(Icons.grid_view_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text('Todas las cámaras',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const Spacer(),
              _IconBtn(
                icon: Icons.close,
                tooltip: 'Salir del modo cuadrícula',
                onTap: () => setState(() => _viewMode = _ViewMode.single),
              ),
            ]),
          ),
          // Grid
          Expanded(
            child: _GridLayout(
              cameras: cameras,
              controllers: _gridControllers,
              ready: _gridReady,
              onTap: (index) => _exitGridMode(index),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Error states ───────────────────────────────────────────────────────────

  Widget _buildNotConfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_outlined,
              color: AppColors.textSecondary, size: 56),
          const SizedBox(height: 20),
          Text('No hay cámaras configuradas',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Ve a Ajustes → Mis Cámaras para agregar tu cámara IP.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          _ActionChip(
            icon: Icons.add_circle_outline,
            label: 'Agregar cámara',
            onTap: () => context.push('/settings/cameras'),
          ),
        ]),
      ),
    );
  }

  Widget _buildStreamError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.signal_wifi_off_outlined,
              color: AppColors.alertRed, size: 56),
          const SizedBox(height: 20),
          Text('Stream no disponible',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Verifica que MediaMTX esté corriendo y la cámara accesible.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ActionChip(icon: Icons.refresh, label: 'Reintentar', onTap: _retry),
            const SizedBox(width: 10),
            _ActionChip(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () => context.push('/settings/cameras'),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Alert banner (demo simulation) ───────────────────────────────────────────

class _AlertBanner extends StatefulWidget {
  final SecurityEventModel event;
  final VoidCallback onDismiss;

  const _AlertBanner({required this.event, required this.onDismiss});

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner>
    with TickerProviderStateMixin {
  // Slide-in from top
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  // Pulsing red glow on the icon
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  // Progress bar draining to zero
  late AnimationController _progressCtrl;

  static const _autoDismissDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(_pulseCtrl);

    _progressCtrl = AnimationController(
        vsync: this, duration: _autoDismissDuration);
    _progressCtrl.forward().whenComplete(_dismiss);

    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    _slideCtrl.reverse().whenComplete(widget.onDismiss);
  }

  String get _confidencePct {
    final score = widget.event.confidenceScore;
    if (score == null) return '';
    return '${(score * 100).toStringAsFixed(0)}% de certeza';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12, right: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF1A0A0A),
              border: Border.all(color: AppColors.alertRed.withAlpha(200), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.alertRed.withAlpha(100),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Red header strip ──────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.alertRed,
                          const Color(0xFFB71C1C),
                        ],
                      ),
                    ),
                    child: Row(children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnim.value,
                          child: const Icon(Icons.warning_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '⚠ ALERTA DE SEGURIDAD',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                    ]),
                  ),
                  // ── Body ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(children: [
                      // Icon circle
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.alertRed.withAlpha(30),
                          border: Border.all(
                              color: AppColors.alertRed.withAlpha(120)),
                        ),
                        child: const Icon(Icons.key_off_outlined,
                            color: AppColors.alertRed, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Intento de ganzúa detectado',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _confidencePct,
                              style: GoogleFonts.inter(
                                color: AppColors.alertRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('HH:mm:ss').format(
                                  widget.event.createdAt.toLocal()),
                              style: GoogleFonts.robotoMono(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Critical badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.alertRed.withAlpha(120)),
                        ),
                        child: Text('Crítico',
                            style: GoogleFonts.inter(
                              color: AppColors.alertRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ]),
                  ),
                  // ── Auto-dismiss progress bar ─────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 1.0 - _progressCtrl.value,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.alertRed.withAlpha(180)),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Grid layout widget ────────────────────────────────────────────────────────

class _GridLayout extends StatelessWidget {
  final List<CameraConfigModel> cameras;
  final Map<String, VideoPlayerController> controllers;
  final Map<String, bool> ready;
  final void Function(int index) onTap;

  const _GridLayout({
    required this.cameras,
    required this.controllers,
    required this.ready,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = cameras.length;
    if (count == 0) return const Center(child: Text('Sin cámaras', style: TextStyle(color: Colors.white54)));

    // Single: full screen
    if (count == 1) {
      return _GridCell(
        camera: cameras[0],
        controller: controllers[cameras[0].id],
        isReady: ready[cameras[0].id] ?? false,
        onTap: () => onTap(0),
        showLabel: false,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count <= 2 ? 1 : 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: count <= 2
            ? (MediaQuery.of(context).size.width /
                (MediaQuery.of(context).size.height / 2 - 60))
            : 16 / 9,
      ),
      itemCount: count,
      itemBuilder: (_, i) => _GridCell(
        camera: cameras[i],
        controller: controllers[cameras[i].id],
        isReady: ready[cameras[i].id] ?? false,
        onTap: () => onTap(i),
        showLabel: true,
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final CameraConfigModel camera;
  final VideoPlayerController? controller;
  final bool isReady;
  final VoidCallback onTap;
  final bool showLabel;

  const _GridCell({
    required this.camera,
    required this.controller,
    required this.isReady,
    required this.onTap,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          // Video or placeholder
          Container(color: const Color(0xFF0A0F1E)),
          if (isReady && controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller!.value.size.height,
                child: VideoPlayer(controller!),
              ),
            )
          else
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2),
                ),
                const SizedBox(height: 8),
                Text('Conectando…',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 11)),
              ]),
            ),
          // Camera name label
          if (showLabel)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(180),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.videocam_outlined,
                      color: Colors.white70, size: 13),
                  const SizedBox(width: 5),
                  Text(camera.name,
                      style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.fullscreen,
                      color: Colors.white38, size: 16),
                ]),
              ),
            ),
          // Tap ripple border
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: AppColors.accent.withAlpha(40),
                highlightColor: Colors.transparent,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(46),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      );
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _LiveBadge extends StatefulWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (widget.isLive ? AppColors.alertRed : AppColors.textMuted)
              .withAlpha(230),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Opacity(
              opacity: widget.isLive ? 0.5 + _pulse.value * 0.5 : 1.0,
              child: Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(widget.isLive ? 'EN VIVO' : 'OFFLINE',
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ]),
      );
}
