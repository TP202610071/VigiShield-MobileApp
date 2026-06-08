import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/models/security_event_model.dart';
import '../../providers/camera_provider.dart';
import '../../providers/event_provider.dart';

enum _ViewMode { single, grid, ai }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  // ── libmpv player (single view) ──────────────────────────────────────────────
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<PlayerLog>? _logSub;
  bool _isPlaying = false;
  // True once libmpv has actually decoded a video frame (width > 0). mpv reports
  // `playing=true` as soon as it connects — BEFORE the first keyframe is decoded
  // — so on this camera (long keyframe interval) we'd hide the spinner and show a
  // black frame with no recovery. We gate the overlay + watchdog on real video.
  bool _hasVideo = false;
  String? _error;

  // Non-destructive recovery. libmpv's `error` stream fires for benign demux
  // warnings too, so we DON'T re-open on every error (that interrupts a healthy
  // stream and causes the "blink"). Instead a stall watchdog only re-opens when
  // playback is genuinely stopped for several seconds. A separate "stable" timer
  // clears the failure budget after sustained playback, so a brief 1-2 s play
  // can't reset the count and make us thrash.
  Timer? _reopenTimer;   // pending re-open after a stall/failure
  Timer? _stallTimer;    // fires recovery if not playing for a grace window
  Timer? _stableTimer;   // clears failure budget after sustained playback
  int _rtspFailures = 0; // consecutive RTSP failures (→ HLS fallback at 3)
  int _hlsFailures = 0;  // consecutive HLS failures (→ hard error eventually)
  bool _opening = false; // guards against overlapping open() calls

  // Prefer RTSP (≈1-2 s latency, no HLS segment buffering). If RTSP fails
  // repeatedly we fall back to the always-works HLS URL (≈higher latency).
  bool _useRtsp = true;

  // Debug: which protocol is actually playing right now ('RTSP' / 'HLS' / '—').
  String _activeProtocol = '—';
  bool _rtspFellBack = false;

  // ── View modes ──────────────────────────────────────────────────────────────
  _ViewMode _viewMode = _ViewMode.single;

  // ── Multi-cam grid ──────────────────────────────────────────────────────────
  final Map<String, Player> _gridPlayers = {};
  final Map<String, VideoController> _gridControllers = {};

  // ── Screenshot ──────────────────────────────────────────────────────────────
  bool _savingScreenshot = false;

  // ── AI view (polls annotated frames from Python backend on :5050) ───────────
  Timer? _aiFrameTimer;
  Uint8List? _aiFrame;
  final _aiDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
    responseType: ResponseType.bytes,
  ));

  // Live detection status (current activity, suspicious flag, objects, faces),
  // polled from /status/{camId} so the AI view can show a banner.
  Timer? _aiStatusTimer;
  Map<String, dynamic>? _aiStatus;
  final _statusDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
    responseType: ResponseType.json,
  ));

  // ── Real-event live alert ────────────────────────────────────────────────────
  Timer? _eventPollTimer;
  DateTime _lastSeenEventTime = DateTime.now().toUtc();
  bool _showLiveAlert = false;
  SecurityEventModel? _liveAlertEvent;
  // Client-side de-dup: don't re-show a banner for the same event type within
  // this window, on top of the backend's per-type cooldown.
  final Map<String, DateTime> _alertCooldownByType = {};
  static const _clientAlertCooldown = Duration(seconds: 45);

  // ── Orientation guard ────────────────────────────────────────────────────────
  bool _isActive = true;

  // Shared 1 Hz clock for the on-screen time.
  final Stream<void> _clock =
      Stream<void>.periodic(const Duration(seconds: 1)).asBroadcastStream();

  // ──────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    // Orientation is owned by MainShell (camera tab = landscape). This screen
    // must NOT set orientation itself — it lives in an IndexedStack and stays
    // alive on other tabs, so forcing landscape here rotates the other tabs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStream();
      _startEventPolling();
    });
  }

  @override
  void deactivate() {
    _isActive = false;
    _cancelRecoveryTimers();
    _stopAiFramePoller();
    _player?.pause();
    for (final p in _gridPlayers.values) { p.pause(); }
    super.deactivate();
  }

  // Grep logcat with:  adb logcat | grep -E "VS-CAM|VS-MPV"
  void _log(String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 23);
    final tag = msg.startsWith('mpv') ? 'VS-MPV' : 'VS-CAM';
    debugPrint('[$tag $t] $msg');
  }

  void _cancelRecoveryTimers() {
    _reopenTimer?.cancel();
    _stallTimer?.cancel();
    _stableTimer?.cancel();
  }

  /// Clear pending recovery timers and the failure budget. When [forceRtsp] is
  /// set we also switch back to preferring RTSP (used on explicit user retry).
  void _resetStreamRecovery({bool forceRtsp = false}) {
    _cancelRecoveryTimers();
    _rtspFailures = 0;
    _hlsFailures = 0;
    if (forceRtsp) { _useRtsp = true; _rtspFellBack = false; }
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;
    // Re-open the live stream — the live window has moved on while we were away.
    // Give RTSP a fresh chance; cancel any stale recovery timers first so we
    // don't stack opens (a cause of the old re-connect loop).
    if (_viewMode == _ViewMode.single) {
      _cancelRecoveryTimers();
      _rtspFailures = 0;
      _hlsFailures = 0;
      _openStream();
    }
    for (final p in _gridPlayers.values) { p.play(); }
    if (_viewMode == _ViewMode.ai) _startAiFramePoller();
  }

  @override
  void dispose() {
    _isActive = false;
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _cancelRecoveryTimers();
    _stopAiFramePoller();
    _eventPollTimer?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _widthSub?.cancel();
    _logSub?.cancel();
    _player?.dispose();
    for (final p in _gridPlayers.values) { p.dispose(); }
    _aiDio.close();
    _statusDio.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player?.pause();
      for (final p in _gridPlayers.values) { p.pause(); }
    } else if (state == AppLifecycleState.resumed) {
      if (_isActive && _viewMode == _ViewMode.single) _openStream();
      for (final p in _gridPlayers.values) { p.play(); }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Event polling — real-time security alerts from the AI backend
  // ──────────────────────────────────────────────────────────────────────────────

  void _startEventPolling() {
    _eventPollTimer?.cancel();
    _lastSeenEventTime = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
    _eventPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkNewEvents());
  }

  Future<void> _checkNewEvents() async {
    if (!mounted) return;
    await context.read<EventProvider>().fetchEvents(refresh: true);
    if (!mounted) return;
    final events = context.read<EventProvider>().events;
    if (events.isEmpty) return;

    final newest = events.first;
    final isNew = newest.createdAt.isAfter(_lastSeenEventTime);
    final isAlertable = newest.eventType != 'FaceRecognized' &&
        newest.riskLevel != 'None' &&
        newest.riskLevel != 'Low';
    if (!isNew || !isAlertable) return;

    // Advance the watermark regardless, so we don't re-evaluate this event again.
    _lastSeenEventTime = newest.createdAt;

    // Don't stack on top of a banner that's already showing, and respect a
    // per-type client cooldown so the same situation doesn't re-alert rapidly.
    if (_showLiveAlert) return;
    final lastShown = _alertCooldownByType[newest.eventType];
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < _clientAlertCooldown) {
      return;
    }
    _alertCooldownByType[newest.eventType] = DateTime.now();
    HapticFeedback.vibrate();
    if (mounted) setState(() { _liveAlertEvent = newest; _showLiveAlert = true; });
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Stream playback (libmpv)
  // ──────────────────────────────────────────────────────────────────────────────

  Future<void> _initStream() async {
    final provider = context.read<CameraProvider>();
    if (provider.cameras.isEmpty) await provider.fetchCameras();
    if (!mounted) return;

    // Create the player + controller once; reuse across camera switches.
    if (_player == null) {
      _player = Player(
        configuration: const PlayerConfiguration(
          // Ensure RTSP/RTP are allowed (HLS over http(s) already worked).
          protocolWhitelist: [
            'file', 'http', 'https', 'tcp', 'tls', 'crypto', 'data',
            'rtsp', 'rtp', 'udp', 'rtmp', 'hls',
          ],
          // Surface mpv's internal warnings (decode errors, RTSP issues) so we
          // can diagnose freezes/black screens via `player.stream.log`.
          logLevel: MPVLogLevel.warn,
        ),
      );
      _videoController = VideoController(_player!);
      // Minimal RTSP tuning. We deliberately do NOT set mpv's `cache`/`cache-secs`/
      // readahead here: those made libmpv try to create a file-backed cache that
      // FAILS on Android ("lavf: Failed to create file cache" in the logs), leaving
      // it with no buffer to ride out WiFi jitter → freeze. media_kit's default
      // (memory) buffering is the right thing on mobile. We only force:
      //  - TCP transport (no UDP packet loss → fewer decode errors), and
      //  - aid=no: skip the camera's G711 audio track (we never play camera audio).
      final platform = _player!.platform;
      if (platform is NativePlayer) {
        try {
          await platform.setProperty('rtsp-transport', 'tcp');
          await platform.setProperty('aid', 'no');
        } catch (_) {/* property unsupported — ignore, defaults still play */}
      }

      // Pipe mpv's internal logs to the console with a grep-able tag.
      _logSub ??= _player!.stream.log.listen((l) {
        _log('mpv[${l.level}] ${l.prefix}: ${l.text.trim()}');
      });
    }

    // Recovery is driven by mpv's OWN play state (this is the version that was
    // stable). If mpv says it's playing, we leave it alone — we do NOT re-open on
    // transient errors or a momentary black frame (that caused a re-connect thrash
    // loop, visible as many RTSP sessions/second in the MediaMTX log).
    _playingSub ??= _player!.stream.playing.listen((playing) {
      if (!mounted) return;
      _log('playing=$playing');
      setState(() {
        _isPlaying = playing;
        if (playing) _error = null;
      });
      if (playing) {
        _stallTimer?.cancel();
        _reopenTimer?.cancel();
        // Clear the failure budget only after playback SUSTAINS (anti-thrash).
        _stableTimer?.cancel();
        _stableTimer = Timer(const Duration(seconds: 8), () {
          _rtspFailures = 0;
          _hlsFailures = 0;
        });
      } else {
        _stableTimer?.cancel();
        _armStallWatchdog();
      }
    });

    // `width` > 0 means a frame actually decoded. Used ONLY to drop the spinner
    // (so a connected-but-black stream still shows "Conectando…"). It does NOT
    // trigger recovery — that's the play-state listener's job.
    _widthSub ??= _player!.stream.width.listen((w) {
      final hasVideo = (w ?? 0) > 0;
      if (hasVideo != _hasVideo && mounted) {
        _log('width=$w hasVideo=$hasVideo');
        setState(() => _hasVideo = hasVideo);
      }
    });

    // libmpv's error stream fires for benign demux warnings too, so we do NOT
    // re-open here — only the play-state listener recovers, and only on a real stop.
    _errorSub ??= _player!.stream.error.listen((e) => _log('error-stream: $e'));

    await _openStream();
  }

  /// Live URL for the selected camera: RTSP (low latency) unless we've fallen
  /// back to HLS after repeated RTSP failures.
  String? _resolveStreamUrl() {
    final cam = context.read<CameraProvider>().selectedCamera;
    if (cam == null) return null;
    final rtsp = cam.mediaMtxRtspUrl;
    final hls = cam.hlsViewUrl;
    if (_useRtsp && rtsp != null && rtsp.isNotEmpty) return rtsp;
    return (hls != null && hls.isNotEmpty) ? hls : rtsp;
  }

  Future<void> _openStream({String? overrideUrl}) async {
    if (_opening) return; // an open() is already in flight — don't stack them
    final url = overrideUrl ?? _resolveStreamUrl();
    if (url == null || url.isEmpty) {
      if (mounted) setState(() { _error = 'no_config'; });
      return;
    }
    if (_player == null) return;

    _opening = true;
    _hasVideo = false; // new media → no decoded frame yet; show the spinner
    _reopenTimer?.cancel();
    final proto = url.toLowerCase().startsWith('rtsp') ? 'RTSP' : 'HLS';
    _log('openStream $proto url=$url (rtspFails=$_rtspFailures hlsFails=$_hlsFailures)');
    if (mounted) {
      setState(() { _error = null; _activeProtocol = proto; });
    }

    try {
      // play:true starts immediately. libmpv handles the live window and
      // buffering internally. We arm a stall watchdog below in case it never
      // produces a frame (e.g. RTSP refused) so we can fall back.
      await _player!.open(Media(url), play: true);
    } catch (e) {
      _log('open() threw: $e');
      _onRecoverableFailure();
    } finally {
      _opening = false;
    }
    // If playback doesn't start within the grace window, recover.
    _armStallWatchdog();
  }

  /// Arm (or re-arm) the stall watchdog. If the stream is not playing when it
  /// fires, we treat it as a failure and recover. Cancelled as soon as the
  /// `playing` stream reports true, so a healthy stream never triggers it.
  void _armStallWatchdog() {
    if (!mounted || !_isActive || _viewMode != _ViewMode.single) return;
    _stallTimer?.cancel();
    // 10s grace tolerates the camera's keyframe wait on a fresh connect. We only
    // recover if mpv is genuinely NOT playing — never re-open a stream mpv
    // considers healthy (that thrash was the regression).
    _stallTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_isActive || _viewMode != _ViewMode.single) return;
      if (_isPlaying) return; // mpv is playing — leave it alone
      _onRecoverableFailure();
    });
  }

  /// A genuine, sustained failure. Counts toward the protocol's failure budget;
  /// RTSP falls back to HLS after 3, HLS surfaces a hard error after several.
  void _onRecoverableFailure() {
    if (!mounted || !_isActive || _viewMode != _ViewMode.single) return;
    _log('recoverableFailure (useRtsp=$_useRtsp, playing=$_isPlaying, hasVideo=$_hasVideo)');

    if (_useRtsp) {
      _rtspFailures++;
      if (_rtspFailures >= 3) {
        // RTSP can't sustain here (firewall / network) — fall back to HLS.
        _log('RTSP failed 3x → falling back to HLS');
        _useRtsp = false;
        _rtspFellBack = true;
        _rtspFailures = 0;
      }
      _reopenSoon();
      return;
    }

    _hlsFailures++;
    if (_hlsFailures > 6) {
      if (mounted) setState(() { _error = 'stream_error'; });
      _hlsFailures = 0;
      return;
    }
    _reopenSoon();
  }

  void _reopenSoon() {
    _stallTimer?.cancel();
    _reopenTimer?.cancel();
    if (mounted) setState(() { _error = null; });
    _reopenTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _isActive && _viewMode == _ViewMode.single) _openStream();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // AI view — polls annotated JPEG frames from the Python backend
  // ──────────────────────────────────────────────────────────────────────────────

  void _startAiFramePoller() {
    _aiFrameTimer?.cancel();
    final cam = context.read<CameraProvider>().selectedCamera;
    final camId = cam?.id;
    if (camId == null) return;
    final hls = cam?.hlsViewUrl;
    final host = (hls != null && hls.isNotEmpty) ? Uri.parse(hls).host : 'localhost';
    final url = 'http://$host:5050/frame/$camId';
    final statusUrl = 'http://$host:5050/status/$camId';
    _log('AI poller start → $url');
    var frameInFlight = false;
    var gotFirstFrame = false;
    var loggedErr = false;
    _aiFrameTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      // Skip if a request is still in flight so slow frames don't pile up.
      if (!mounted || frameInFlight) return;
      frameInFlight = true;
      try {
        final resp = await _aiDio.get<List<int>>(url);
        if (resp.statusCode == 200 && resp.data != null && mounted) {
          if (!gotFirstFrame) { gotFirstFrame = true; _log('AI first frame ok (${resp.data!.length}B)'); }
          setState(() => _aiFrame = Uint8List.fromList(resp.data!));
        }
      } catch (e) {
        if (!loggedErr) { loggedErr = true; _log('AI frame fetch FAILED: $e'); }
      } finally {
        frameInFlight = false;
      }
    });
    // Status banner — lower frequency than the frame poller.
    _aiStatusTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      if (!mounted) return;
      try {
        final resp = await _statusDio.get<Map<String, dynamic>>(statusUrl);
        if (resp.statusCode == 200 && resp.data != null && mounted) {
          setState(() => _aiStatus = resp.data);
        }
      } catch (_) {/* backend not ready — keep polling */}
    });
  }

  void _stopAiFramePoller() {
    _aiFrameTimer?.cancel();
    _aiFrameTimer = null;
    _aiStatusTimer?.cancel();
    _aiStatusTimer = null;
    _aiFrame = null;
    _aiStatus = null;
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Screenshot (captures the decoded video frame directly via libmpv)
  // ──────────────────────────────────────────────────────────────────────────────

  Future<void> _takeScreenshot() async {
    if (_savingScreenshot) return;
    setState(() => _savingScreenshot = true);
    try {
      Uint8List? bytes;
      if (_viewMode == _ViewMode.ai) {
        bytes = _aiFrame;
      } else {
        bytes = await _player?.screenshot();
      }
      if (bytes == null) throw Exception('No frame available');
      final name = 'vigishield_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      await Gal.putImageBytes(bytes, name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Captura guardada en galería',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.safeGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _savingScreenshot = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Camera switching / grid / retry
  // ──────────────────────────────────────────────────────────────────────────────

  Future<void> _switchCamera(int index) async {
    context.read<CameraProvider>().selectCamera(index);
    _stopAiFramePoller();
    _resetStreamRecovery(forceRtsp: true); // try low-latency RTSP for new camera
    await _openStream();
    if (_viewMode == _ViewMode.ai) _startAiFramePoller();
  }

  Future<void> _retry() async {
    _resetStreamRecovery(forceRtsp: true); // give RTSP another chance
    await context.read<CameraProvider>().fetchCameras();
    if (!mounted) return;
    await _openStream();
  }

  /// Force a fresh RTSP attempt (tapped from the debug badge). Useful after
  /// opening a firewall port — the stream may have latched onto HLS.
  Future<void> _forceRtsp() async {
    _resetStreamRecovery(forceRtsp: true);
    await _openStream();
  }

  Future<void> _enterGridMode() async {
    final cameras = context.read<CameraProvider>().cameras;
    setState(() => _viewMode = _ViewMode.grid);
    for (final cam in cameras) {
      // RTSP for low latency; HLS fallback if a camera has no RTSP URL.
      final url = (cam.mediaMtxRtspUrl?.isNotEmpty ?? false)
          ? cam.mediaMtxRtspUrl!
          : cam.hlsViewUrl;
      if (url == null || url.isEmpty || _gridPlayers.containsKey(cam.id)) continue;
      final p = Player();
      if (p.platform is NativePlayer) {
        final np = p.platform as NativePlayer;
        await np.setProperty('rtsp-transport', 'tcp');
        await np.setProperty('aid', 'no');
      }
      _gridPlayers[cam.id] = p;
      _gridControllers[cam.id] = VideoController(p);
      try {
        await p.open(Media(url), play: true);
      } catch (_) {/* cell shows spinner */}
      if (mounted) setState(() {});
    }
  }

  void _exitGridMode(int cameraIndex) {
    context.read<CameraProvider>().selectCamera(cameraIndex);
    setState(() => _viewMode = _ViewMode.single);
    _resetStreamRecovery();
    _openStream();
  }

  void _toggleAiView() {
    if (_viewMode == _ViewMode.ai) {
      // Back to live — re-open the stream (it was stopped to free the phone for
      // the AI frame poll). The play-state watchdog handles a slow first frame.
      _stopAiFramePoller();
      setState(() => _viewMode = _ViewMode.single);
      _resetStreamRecovery();
      _openStream();
    } else {
      // Entering AI: STOP the live RTSP player so it doesn't compete with the AI
      // frame poll (decode + bandwidth) — that contention was making the AI
      // stream fail to load. stop() fully releases the RTSP session.
      _cancelRecoveryTimers();
      _player?.stop();
      _stopAiFramePoller();
      _aiFrame = null;
      setState(() => _viewMode = _ViewMode.ai);
      _startAiFramePoller();
    }
  }

  void _showCameraSettings() {
    final camId = context.read<CameraProvider>().selectedCamera?.id;
    if (camId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _CameraSettingsSheet(cameraId: camId),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      final isLandscape = orientation == Orientation.landscape;
      return Scaffold(
        backgroundColor: Colors.black,
        body: switch (_viewMode) {
          _ViewMode.grid => _buildGrid(isLandscape),
          _ViewMode.ai => _buildAiView(isLandscape),
          _ViewMode.single => _buildSingle(isLandscape),
        },
      );
    });
  }

  // ── Single view ─────────────────────────────────────────────────────────────

  Widget _buildSingle(bool isLandscape) {
    return Stack(fit: StackFit.expand, children: [
      _buildSingleContent(),
      _buildTopBar(isLandscape),
      _buildBottomBar(isLandscape),
      if (_showLiveAlert && _liveAlertEvent != null)
        _AlertBanner(
          event: _liveAlertEvent!,
          onDismiss: () => setState(() => _showLiveAlert = false),
        ),
    ]);
  }

  Widget _buildSingleContent() {
    if (_error == 'no_config') return _buildNotConfigured();
    if (_error == 'stream_error') return _buildStreamError();

    final ctrl = _videoController;
    return Stack(fit: StackFit.expand, children: [
      if (ctrl != null)
        InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Video(
            controller: ctrl,
            controls: NoVideoControls,
            fit: BoxFit.contain,
            fill: Colors.black,
          ),
        ),
      // Connecting overlay — shown until mpv is playing or a real frame decoded.
      if (!_hasVideo && !_isPlaying && _error == null)
        Container(
          color: Colors.black.withAlpha(140),
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
              SizedBox(height: 16),
              Text('Conectando…',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
    ]);
  }

  // ── AI view ─────────────────────────────────────────────────────────────────

  Widget _buildAiView(bool isLandscape) {
    return Stack(fit: StackFit.expand, children: [
      _buildAiContent(),
      _buildTopBar(isLandscape, aiMode: true),
      // Live detection status banner (activity + suspicious flag + chips).
      if (_aiStatus != null)
        Positioned(
          top: (isLandscape ? 12 : MediaQuery.of(context).padding.top + 12) + 40,
          left: 12, right: 12,
          child: _AiStatusBanner(status: _aiStatus!),
        ),
      _buildBottomBar(isLandscape),
      if (_showLiveAlert && _liveAlertEvent != null)
        _AlertBanner(
          event: _liveAlertEvent!,
          onDismiss: () => setState(() => _showLiveAlert = false),
        ),
    ]);
  }

  Widget _buildAiContent() {
    final frame = _aiFrame;
    if (frame != null) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Image.memory(frame, fit: BoxFit.contain, gaplessPlayback: true),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
          const SizedBox(height: 20),
          Text('Conectando al motor AI…',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Asegúrate de que el backend Python esté corriendo.\n'
            'Los frames aparecerán cuando se procese el primer fotograma.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
          ),
        ]),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool isLandscape, {bool aiMode = false}) {
    final provider = context.watch<CameraProvider>();
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
        child: Row(children: [
          if (aiMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(220),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('AI DETECCIÓN',
                  style: GoogleFonts.inter(
                      color: Colors.black, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
            )
          else ...[
            _LiveBadge(isLive: _isPlaying),
            const SizedBox(width: 6),
            // Debug protocol tag — tap to force a fresh RTSP attempt.
            _ProtocolTag(
              protocol: _activeProtocol,
              fellBack: _rtspFellBack,
              onTap: _forceRtsp,
            ),
          ],
          const SizedBox(width: 10),
          if (camName != null)
            Expanded(
              child: Text(camName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            )
          else
            const Spacer(),
          if (hasMultiple && !aiMode) ...[
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.grid_view_rounded, tooltip: 'Ver todas', onTap: _enterGridMode),
            const SizedBox(width: 8),
          ],
          StreamBuilder(
            stream: _clock,
            builder: (_, __) => Text(
              DateFormat('HH:mm:ss').format(DateTime.now()),
              style: GoogleFonts.robotoMono(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isLandscape) {
    final provider = context.watch<CameraProvider>();
    final cameras = provider.cameras;
    final selectedIdx = cameras.isEmpty
        ? 0
        : cameras.indexOf(provider.selectedCamera ?? cameras.first);

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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.accent : Colors.white.withAlpha(46),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected ? AppColors.accent : Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.videocam_outlined,
                              color: selected ? Colors.black : Colors.white70, size: 13),
                          const SizedBox(width: 5),
                          Text(cameras[i].name,
                              style: GoogleFonts.inter(
                                  color: selected ? Colors.black : Colors.white70,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    );
                  }),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          _IconBtn(
            icon: _viewMode == _ViewMode.ai
                ? Icons.videocam_outlined
                : Icons.psychology_outlined,
            tooltip: _viewMode == _ViewMode.ai ? 'Vista en vivo' : 'Vista AI',
            onTap: _toggleAiView,
          ),
          const SizedBox(width: 8),
          if (_error == null) ...[
            _IconBtn(
              icon: _savingScreenshot
                  ? Icons.hourglass_bottom_outlined
                  : Icons.camera_alt_outlined,
              tooltip: 'Captura de pantalla',
              onTap: _takeScreenshot,
            ),
            const SizedBox(width: 8),
          ],
          _IconBtn(
            icon: Icons.tune_outlined,
            tooltip: 'Ajustes de cámara',
            onTap: _showCameraSettings,
          ),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.refresh, tooltip: 'Reconectar', onTap: _retry),
        ]),
      ),
    );
  }

  // ── Grid view ───────────────────────────────────────────────────────────────

  Widget _buildGrid(bool isLandscape) {
    final cameras = context.watch<CameraProvider>().cameras;
    return Stack(children: [
      SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.black,
            child: Row(children: [
              const Icon(Icons.grid_view_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text('Todas las cámaras',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              _IconBtn(
                icon: Icons.close,
                tooltip: 'Salir del modo cuadrícula',
                onTap: () {
                  setState(() => _viewMode = _ViewMode.single);
                  _resetStreamRecovery();
                  _openStream();
                },
              ),
            ]),
          ),
          Expanded(
            child: _GridLayout(
              cameras: cameras,
              controllers: _gridControllers,
              onTap: _exitGridMode,
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Error states ─────────────────────────────────────────────────────────────

  Widget _buildNotConfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_outlined, color: AppColors.textSecondary, size: 56),
          const SizedBox(height: 20),
          Text('No hay cámaras configuradas',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Ve a Ajustes → Mis Cámaras para agregar tu cámara IP.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
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
          const Icon(Icons.signal_wifi_off_outlined, color: AppColors.alertRed, size: 56),
          const SizedBox(height: 20),
          Text('Stream no disponible',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Verifica que MediaMTX esté corriendo y la cámara accesible.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
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

// ── Camera settings bottom sheet ─────────────────────────────────────────────

class _CameraSettingsSheet extends StatefulWidget {
  final String cameraId;
  const _CameraSettingsSheet({required this.cameraId});

  @override
  State<_CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<_CameraSettingsSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Image
  double _brightness = 50, _contrast = 50, _saturation = 50, _sharpness = 50;
  bool _wdr = false;
  String _night = 'auto'; // auto | open | close
  // Video
  int _bitrate = 2048, _fps = 25, _gop = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final m = await context.read<CameraProvider>().loadCameraControls(widget.cameraId);
    if (!mounted) return;
    if (m == null) {
      setState(() { _loading = false; _error = 'No se pudo leer la cámara'; });
      return;
    }
    double d(String k, double f) => double.tryParse(m[k] ?? '') ?? f;
    int i(String k, int f) => int.tryParse(m[k] ?? '') ?? f;
    setState(() {
      _loading = false;
      _brightness = d('brightness', 50);
      _contrast = d('contrast', 50);
      _saturation = d('saturation', 50);
      _sharpness = d('sharpness', 50);
      _wdr = (m['wdr'] ?? 'off') == 'on';
      _night = (m['infraredstat'] ?? 'auto');
      _bitrate = i('bps', 2048);
      _fps = i('fps', 25);
      _gop = i('gop', 50);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final settings = <String, String>{
      'brightness': _brightness.round().toString(),
      'contrast': _contrast.round().toString(),
      'saturation': _saturation.round().toString(),
      'sharpness': _sharpness.round().toString(),
      'wdr': _wdr ? 'on' : 'off',
      'infraredstat': _night,
      'bps': _bitrate.toString(),
      'fps': _fps.toString(),
      'gop': _gop.toString(),
    };
    final ok = await context.read<CameraProvider>().applyCameraControls(widget.cameraId, settings);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Ajustes aplicados a la cámara' : 'Error al aplicar ajustes',
          style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: ok ? AppColors.safeGreen : AppColors.alertRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(controller: ctrl, children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Icon(Icons.tune, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Ajustes de Cámara',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text('Valores actuales leídos de la cámara. Mueve y guarda para aplicar en vivo.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 18),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                const Icon(Icons.error_outline, color: AppColors.alertRed, size: 40),
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                _ActionChip(icon: Icons.refresh, label: 'Reintentar', onTap: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                }),
              ]),
            )
          else ...[
            _grpLabel('IMAGEN'),
            _SliderRow(label: 'Brillo', value: _brightness, onChanged: (v) => setState(() => _brightness = v)),
            _SliderRow(label: 'Contraste', value: _contrast, onChanged: (v) => setState(() => _contrast = v)),
            _SliderRow(label: 'Saturación', value: _saturation, onChanged: (v) => setState(() => _saturation = v)),
            _SliderRow(label: 'Nitidez', value: _sharpness, onChanged: (v) => setState(() => _sharpness = v)),
            const SizedBox(height: 8),
            _SwitchRow(label: 'WDR (rango dinámico)', value: _wdr, onChanged: (v) => setState(() => _wdr = v)),
            _ChoiceRow(
              label: 'Visión nocturna',
              value: _night,
              options: const {'auto': 'Automática', 'open': 'Siempre ON', 'close': 'Siempre OFF'},
              onChanged: (v) => setState(() => _night = v),
            ),
            const SizedBox(height: 16),
            _grpLabel('VIDEO'),
            _StepRow(
              label: 'Bitrate', suffix: 'kbps', value: _bitrate, min: 256, max: 4096, step: 256,
              onChanged: (v) => setState(() => _bitrate = v),
            ),
            _StepRow(
              label: 'FPS', suffix: 'fps', value: _fps, min: 5, max: 30, step: 1,
              onChanged: (v) => setState(() => _fps = v),
            ),
            _StepRow(
              label: 'Intervalo keyframe', suffix: 'frames', value: _gop, min: 10, max: 200, step: 5,
              onChanged: (v) => setState(() => _gop = v),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text('Aplicar a la cámara',
                        style: GoogleFonts.inter(
                            color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _grpLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t,
            style: GoogleFonts.inter(
                color: AppColors.accent, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 86,
        child: Text(label,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            thumbColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            overlayColor: AppColors.accent.withAlpha(40),
            trackHeight: 3,
          ),
          child: Slider(value: value.clamp(0, 100), min: 0, max: 100, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 32,
        child: Text(value.round().toString(),
            textAlign: TextAlign.end,
            style: GoogleFonts.robotoMono(color: AppColors.textSecondary, fontSize: 12)),
      ),
    ]);
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accent,
        ),
      ]),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _ChoiceRow({
    required this.label, required this.value,
    required this.options, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.containsKey(value) ? value : options.keys.first,
              dropdownColor: AppColors.surfaceElevated,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
              items: options.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label, suffix;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  const _StepRow({
    required this.label, required this.suffix, required this.value,
    required this.min, required this.max, required this.step, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13)),
        ),
        _stepBtn(Icons.remove, () => onChanged((value - step).clamp(min, max))),
        Container(
          width: 78,
          alignment: Alignment.center,
          child: Text('$value $suffix',
              style: GoogleFonts.robotoMono(color: AppColors.textSecondary, fontSize: 12)),
        ),
        _stepBtn(Icons.add, () => onChanged((value + step).clamp(min, max))),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.accent, size: 16),
        ),
      );
}

// ── Alert banner ─────────────────────────────────────────────────────────────

class _AlertBanner extends StatefulWidget {
  final SecurityEventModel event;
  final VoidCallback onDismiss;

  const _AlertBanner({required this.event, required this.onDismiss});

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _progressCtrl;

  static const _autoDismissDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseCtrl);
    _progressCtrl = AnimationController(vsync: this, duration: _autoDismissDuration)
      ..forward().whenComplete(_dismiss);
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

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(widget.event.riskLevel);
    final label = _labelFor(widget.event.eventType);
    final icon = _iconFor(widget.event.eventType);
    final pct = widget.event.confidenceScore;
    final time = DateFormat('HH:mm:ss').format(widget.event.createdAt.toLocal());
    final sub = [
      _riskLabel(widget.event.riskLevel),
      if (pct != null) '${(pct * 100).toStringAsFixed(0)}%',
      time,
    ].join(' · ');

    // Compact slim banner pinned to the top — no longer covers half the screen.
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12, right: 12,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xF21A0A0A),
              border: Border.all(color: color.withAlpha(200), width: 1),
              boxShadow: [BoxShadow(color: color.withAlpha(70), blurRadius: 12, spreadRadius: 1)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Row(children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: _pulseAnim.value,
                        child: Icon(icon, color: color, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(sub,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.close, color: Colors.white54, size: 16),
                  ]),
                ),
                AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (_, __) => LinearProgressIndicator(
                    value: 1.0 - _progressCtrl.value,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(color.withAlpha(160)),
                    minHeight: 2,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  static Color _colorFor(String risk) => switch (risk) {
        'Critical' || 'High' => AppColors.alertRed,
        'Medium' => AppColors.warningAmber,
        _ => AppColors.safeGreen,
      };

  static String _riskLabel(String risk) => switch (risk) {
        'Critical' => 'Crítico',
        'High' => 'Alto',
        'Medium' => 'Medio',
        'Low' => 'Bajo',
        _ => risk,
      };

  static String _labelFor(String type) => switch (type) {
        'FaceRecognized' => 'Acceso reconocido',
        'UnknownFace' => 'Persona desconocida',
        'LowConfidenceFace' => 'Detección baja confianza',
        'RecurrentUnknownFace' => 'Visitante desconocido recurrente',
        'ForcedAccessAttempt' => 'Intento de acceso forzado',
        'LockpickingAttempt' => 'Intento de ganzúa',
        'Tailgating' => 'Merodeador detectado',
        'Climbing' => 'Escalamiento detectado',
        'Burglary' => 'Robo detectado',
        'PhysicalAggression' => 'Agresión física',
        'Assault' => 'Asalto detectado',
        'Abuse' => 'Abuso detectado',
        'Arrest' => 'Arresto detectado',
        'Stealing' || 'Shoplifting' || 'Robbery' => 'Robo detectado',
        'Vandalism' => 'Vandalismo detectado',
        'Arson' => 'Incendio provocado',
        'Explosion' => 'Explosión detectada',
        'Roadaccidents' => 'Accidente de tráfico',
        'WeaponDetected' => 'Arma detectada',
        _ => type,
      };

  static IconData _iconFor(String type) => switch (type) {
        'FaceRecognized' => Icons.face_outlined,
        'UnknownFace' => Icons.person_off_outlined,
        'LowConfidenceFace' => Icons.help_outline,
        'ForcedAccessAttempt' || 'LockpickingAttempt' => Icons.lock_open_outlined,
        'Tailgating' || 'Climbing' => Icons.directions_walk,
        'Burglary' => Icons.home_work_outlined,
        'PhysicalAggression' || 'Assault' || 'Abuse' => Icons.sports_mma,
        'Stealing' || 'Shoplifting' || 'Robbery' => Icons.shopping_bag_outlined,
        'Vandalism' => Icons.broken_image_outlined,
        'Arson' => Icons.local_fire_department_outlined,
        'Explosion' => Icons.bolt_outlined,
        'Roadaccidents' => Icons.car_crash_outlined,
        'WeaponDetected' => Icons.gpp_bad_outlined,
        _ => Icons.warning_amber_outlined,
      };
}

// ── Grid layout ──────────────────────────────────────────────────────────────

class _GridLayout extends StatelessWidget {
  final List<CameraConfigModel> cameras;
  final Map<String, VideoController> controllers;
  final void Function(int) onTap;

  const _GridLayout({
    required this.cameras,
    required this.controllers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = cameras.length;
    if (count == 0) {
      return const Center(child: Text('Sin cámaras', style: TextStyle(color: Colors.white54)));
    }
    if (count == 1) {
      return _GridCell(
        camera: cameras[0], controller: controllers[cameras[0].id],
        onTap: () => onTap(0), showLabel: false,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count <= 2 ? 1 : 2,
        mainAxisSpacing: 2, crossAxisSpacing: 2,
        childAspectRatio: count <= 2
            ? (MediaQuery.of(context).size.width /
                (MediaQuery.of(context).size.height / 2 - 60))
            : 16 / 9,
      ),
      itemCount: count,
      itemBuilder: (_, i) => _GridCell(
        camera: cameras[i], controller: controllers[cameras[i].id],
        onTap: () => onTap(i), showLabel: true,
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final CameraConfigModel camera;
  final VideoController? controller;
  final VoidCallback onTap;
  final bool showLabel;

  const _GridCell({
    required this.camera, required this.controller,
    required this.onTap, required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          Container(color: const Color(0xFF0A0F1E)),
          if (controller != null)
            Video(controller: controller!, controls: NoVideoControls, fit: BoxFit.cover, fill: Colors.black)
          else
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                ),
                const SizedBox(height: 8),
                Text('Conectando…',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ]),
            ),
          if (showLabel)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withAlpha(180), Colors.transparent],
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.videocam_outlined, color: Colors.white70, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(camera.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  const Icon(Icons.fullscreen, color: Colors.white38, size: 16),
                ]),
              ),
            ),
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

class _ProtocolTag extends StatelessWidget {
  final String protocol; // 'RTSP' | 'HLS' | '—'
  final bool fellBack;
  final VoidCallback onTap;

  const _ProtocolTag({
    required this.protocol,
    required this.fellBack,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRtsp = protocol == 'RTSP';
    final color = isRtsp
        ? AppColors.safeGreen
        : (protocol == 'HLS' ? AppColors.warningAmber : AppColors.textMuted);
    final label = fellBack && !isRtsp ? 'HLS ⚠' : protocol;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: isRtsp
            ? 'Modo RTSP (tiempo real). Toca para reconectar.'
            : 'Modo HLS (con retraso). Toca para forzar RTSP.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(140)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.robotoMono(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── AI live status banner ─────────────────────────────────────────────────────
// Shows the activity model's current prediction + a flashing SUSPICIOUS pill and
// chips for detected persons / objects / faces / behavior alerts. Driven by the
// Python /status/{camId} endpoint.

class _AiStatusBanner extends StatefulWidget {
  final Map<String, dynamic> status;
  const _AiStatusBanner({required this.status});

  @override
  State<_AiStatusBanner> createState() => _AiStatusBannerState();
}

class _AiStatusBannerState extends State<_AiStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final activity = (s['activity'] as Map?)?.cast<String, dynamic>() ?? const {};
    final label = (activity['label'] ?? '—').toString();
    final conf = (activity['confidence'] is num) ? (activity['confidence'] as num).toDouble() : 0.0;
    final suspicious = s['suspicious'] == true;
    final persons = (s['persons'] is num) ? (s['persons'] as num).toInt() : 0;
    final objects = (s['objects'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final faces = (s['faces'] as List?) ?? const [];
    final alerts = (s['alerts'] as List?)?.map((e) => e.toString()).toList() ?? const [];

    final color = suspicious ? AppColors.alertRed : AppColors.safeGreen;

    final chips = <Widget>[
      if (persons > 0) _chip(Icons.person_outline, '$persons', AppColors.accent),
      for (final o in objects)
        _chip(Icons.category_outlined, o,
            _isWeapon(o) ? AppColors.alertRed : AppColors.warningAmber),
      for (final f in faces)
        _chip(
          (f is Map && f['known'] == true) ? Icons.verified_user_outlined : Icons.help_outline,
          (f is Map ? (f['name'] ?? '?') : '?').toString(),
          (f is Map && f['known'] == true) ? AppColors.safeGreen : AppColors.alertRed,
        ),
    ];

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final glow = suspicious ? (0.4 + _pulse.value * 0.6) : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(180),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(suspicious ? 230 : 140), width: 1.5),
            boxShadow: suspicious
                ? [BoxShadow(color: color.withAlpha((120 * glow).round()), blurRadius: 16, spreadRadius: 2)]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(suspicious ? Icons.warning_amber_rounded : Icons.psychology_outlined,
                  color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text('$label · ${(conf * 100).toStringAsFixed(0)}%',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.robotoMono(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              if (suspicious)
                Opacity(
                  opacity: 0.6 + _pulse.value * 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('SOSPECHOSO',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.safeGreen.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.safeGreen.withAlpha(120)),
                  ),
                  child: Text('NORMAL',
                      style: GoogleFonts.inter(
                          color: AppColors.safeGreen, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
            ]),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
            ],
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final a in alerts)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.priority_high_rounded, color: AppColors.warningAmber, size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(a,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AppColors.warningAmber, fontSize: 11)),
                    ),
                  ]),
                ),
            ],
          ]),
        );
      },
    );
  }

  static bool _isWeapon(String name) =>
      const {'knife', 'scissors', 'baseball bat'}.contains(name.toLowerCase());

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
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
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
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

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (widget.isLive ? AppColors.alertRed : AppColors.textMuted).withAlpha(230),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Opacity(
              opacity: widget.isLive ? 0.5 + _pulse.value * 0.5 : 1.0,
              child: Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
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
