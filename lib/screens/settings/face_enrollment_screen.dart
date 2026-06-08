import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/face_service.dart';

/// One guided pose the user must hold for a moment before we capture it.
class _PoseStep {
  final String key;
  final String instruction;
  final IconData icon;
  final bool Function(double yaw, double pitch) matches;
  const _PoseStep(this.key, this.instruction, this.icon, this.matches);
}

/// Real-time guided facial enrollment (FaceID/KYC-style). Detects the face
/// on-device with ML Kit, validates framing/pose, prompts the user, and
/// auto-captures several angles, then uploads them as the person's profile.
class FaceEnrollmentScreen extends StatefulWidget {
  final String personName;
  const FaceEnrollmentScreen({super.key, required this.personName});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  late final FaceDetector _detector;

  bool _initializing = true;
  String? _error;

  bool _detecting = false;  // an ML Kit call is in flight
  bool _busy = false;       // capturing or uploading (pause detection)
  bool _uploading = false;

  int _stepIndex = 0;
  int _stableFrames = 0;
  final List<XFile> _captured = [];

  String _hint = 'Coloca tu rostro en el óvalo';
  bool _poseGood = false; // current frame satisfies the active step
  bool _flash = false;    // brief capture flash

  static const _framesToHold = 8; // ~0.5s of a held pose before capturing

  static const _steps = <_PoseStep>[
    _PoseStep('center', 'Mira al frente', Icons.center_focus_strong,
        _centerPose),
    _PoseStep('left', 'Gira la cabeza a tu izquierda', Icons.turn_left,
        _leftPose),
    _PoseStep('right', 'Gira la cabeza a tu derecha', Icons.turn_right,
        _rightPose),
    _PoseStep('up', 'Levanta un poco la barbilla', Icons.keyboard_arrow_up,
        _upPose),
  ];

  static bool _centerPose(double yaw, double pitch) => yaw.abs() < 14 && pitch.abs() < 16;
  static bool _leftPose(double yaw, double pitch) => yaw > 16;
  static bool _rightPose(double yaw, double pitch) => yaw < -16;
  static bool _upPose(double yaw, double pitch) => pitch > 11;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      _camera = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_processImage);
      setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'No se pudo abrir la cámara.\n$e';
        });
      }
    }
  }

  // ── Frame processing ──────────────────────────────────────────────────────

  Future<void> _processImage(CameraImage image) async {
    if (_detecting || _busy || !mounted) return;
    _detecting = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      _evaluate(faces, image.width.toDouble(), image.height.toDouble());
    } catch (_) {
      // transient detector error — ignore this frame
    } finally {
      _detecting = false;
    }
  }

  void _evaluate(List<Face> faces, double imgW, double imgH) {
    if (!mounted || _busy) return;
    String hint;
    bool poseGood = false;

    if (faces.isEmpty) {
      hint = 'Coloca tu rostro en el óvalo';
      _stableFrames = 0;
    } else if (faces.length > 1) {
      hint = 'Solo una persona a la vez';
      _stableFrames = 0;
    } else {
      final f = faces.first;
      final bb = f.boundingBox;
      final areaRatio = (bb.width * bb.height) / (imgW * imgH);
      final yaw = f.headEulerAngleY ?? 0;
      final pitch = f.headEulerAngleX ?? 0;
      final step = _steps[_stepIndex];

      if (areaRatio < 0.045) {
        hint = 'Acércate un poco';
        _stableFrames = 0;
      } else if (areaRatio > 0.40) {
        hint = 'Aléjate un poco';
        _stableFrames = 0;
      } else if (!step.matches(yaw, pitch)) {
        hint = step.instruction;
        _stableFrames = 0;
      } else {
        poseGood = true;
        hint = 'Mantén la posición…';
        _stableFrames++;
        if (_stableFrames >= _framesToHold) {
          _stableFrames = 0;
          _capture();
        }
      }
    }

    setState(() {
      _hint = hint;
      _poseGood = poseGood;
    });
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      final compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      final raw = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + compensation) % 360
          : (sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(raw);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ── Capture + upload ──────────────────────────────────────────────────────

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    _busy = true;
    if (mounted) setState(() => _flash = true);
    try {
      await controller.stopImageStream();
      final shot = await controller.takePicture();
      _captured.add(shot);
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _flash = false);

      if (_stepIndex >= _steps.length - 1) {
        await _upload();
        return;
      }
      setState(() => _stepIndex++);
      await controller.startImageStream(_processImage);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al capturar: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _upload() async {
    if (mounted) setState(() => _uploading = true);
    try {
      final service = FaceService(context.read<ApiClient>());
      await service.addFace(widget.personName, _captured);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'No se pudo registrar el rostro.\n$e';
        });
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? _buildError()
          : _initializing
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
              : _buildScanner(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppColors.alertRed, size: 52),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Volver', style: GoogleFonts.inter(color: AppColors.accent)),
            ),
          ]),
        ),
      );

  Widget _buildScanner() {
    final controller = _controller!;
    final ringColor = _poseGood ? AppColors.safeGreen : AppColors.accent;

    return Stack(fit: StackFit.expand, children: [
      // Camera preview
      FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1080,
          height: controller.value.previewSize?.width ?? 1920,
          child: CameraPreview(controller),
        ),
      ),
      // Dim overlay + oval cutout guide
      CustomPaint(
        size: Size.infinite,
        painter: _OvalMaskPainter(borderColor: ringColor),
      ),
      if (_flash) Container(color: Colors.white.withAlpha(160)),

      // Top: progress dots + name
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              Expanded(
                child: Text('Registrando a ${widget.personName}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final done = i < _captured.length;
                final active = i == _stepIndex;
                return Container(
                  width: active ? 26 : 18, height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.safeGreen
                        : (active ? AppColors.accent : Colors.white24),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),

      // Bottom: instruction / hint
      Positioned(
        left: 0, right: 0, bottom: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(context).padding.bottom + 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withAlpha(210), Colors.transparent],
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_uploading) ...[
              const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
              const SizedBox(height: 14),
              Text('Registrando rostro…',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ] else ...[
              Icon(_steps[_stepIndex].icon,
                  color: _poseGood ? AppColors.safeGreen : Colors.white, size: 30),
              const SizedBox(height: 10),
              Text(_steps[_stepIndex].instruction,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_hint,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: _poseGood ? AppColors.safeGreen : Colors.white70, fontSize: 13)),
            ],
          ]),
        ),
      ),
    ]);
  }
}

/// Paints a translucent mask with a clear oval "face here" cutout + ring.
class _OvalMaskPainter extends CustomPainter {
  final Color borderColor;
  _OvalMaskPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.72,
      height: size.width * 0.95,
    );
    final mask = Path()..addRect(Offset.zero & size);
    final hole = Path()..addOval(oval);
    final cut = Path.combine(PathOperation.difference, mask, hole);
    canvas.drawPath(cut, Paint()..color = Colors.black.withAlpha(140));
    canvas.drawOval(
      oval,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalMaskPainter old) => old.borderColor != borderColor;
}
