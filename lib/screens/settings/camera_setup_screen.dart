import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/camera_config_model.dart';
import '../../providers/camera_provider.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

class CameraSetupScreen extends StatefulWidget {
  final String? cameraId;
  const CameraSetupScreen({super.key, this.cameraId});

  bool get isEditing => cameraId != null;

  @override
  State<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends State<CameraSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  String _streamMode = 'DirectRtsp';
  final _nameCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '554');
  final _pathCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _hasExistingPassword = false;
  bool _clearPassword = false;
  bool _isDefault = false;

  // Shown after save — backend generates these
  String? _savedHlsUrl;
  String? _savedRtmpPushUrl;
  String? _savedStreamKey;
  String? _savedRtspUrl;
  String? _savedMediaMtxRtspUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  void _loadExisting() {
    if (!widget.isEditing) {
      final count = context.read<CameraProvider>().cameras.length;
      _nameCtrl.text = count == 0 ? 'Entrada principal' : 'Cámara ${count + 1}';
      setState(() => _isDefault = count == 0);
      return;
    }

    final cam = context
        .read<CameraProvider>()
        .cameras
        .where((c) => c.id == widget.cameraId)
        .firstOrNull;

    if (cam == null) return;

    setState(() {
      _streamMode = cam.streamMode;
      _nameCtrl.text = cam.name;
      _ipCtrl.text = cam.cameraIp ?? '';
      _portCtrl.text = cam.cameraPort.toString();
      _pathCtrl.text = cam.cameraPath ?? '';
      _userCtrl.text = cam.cameraUsername ?? '';
      _hasExistingPassword = cam.hasPassword;
      _isDefault = cam.isDefault;
      _savedHlsUrl = cam.hlsViewUrl;
      _savedRtmpPushUrl = cam.rtmpPushUrl;
      _savedStreamKey = cam.streamKey;
      _savedRtspUrl = cam.rtspUrl;
      _savedMediaMtxRtspUrl = cam.mediaMtxRtspUrl;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pathCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    String? password;
    if (_clearPassword) {
      password = '';
    } else if (_passCtrl.text.isNotEmpty) {
      password = _passCtrl.text;
    }

    final req = SaveCameraRequest(
      name: _nameCtrl.text.trim().isEmpty ? 'Cámara' : _nameCtrl.text.trim(),
      streamMode: _streamMode,
      cameraIp: _ipCtrl.text.trim().isEmpty ? null : _ipCtrl.text.trim(),
      cameraPort: int.tryParse(_portCtrl.text) ?? 554,
      cameraPath: _pathCtrl.text.trim().isEmpty ? null : _pathCtrl.text.trim(),
      cameraUsername:
          _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
      cameraPassword: password,
      isDefault: _isDefault,
    );

    final provider = context.read<CameraProvider>();
    final ok = widget.isEditing
        ? await provider.updateCamera(widget.cameraId!, req)
        : await provider.createCamera(req);

    if (!mounted) return;

    if (ok) {
      // Get the saved camera's auto-generated URLs
      final saved = provider.cameras
          .where((c) => widget.isEditing
              ? c.id == widget.cameraId
              : c.name == req.name)
          .firstOrNull;

      setState(() {
        _savedHlsUrl = saved?.hlsViewUrl;
        _savedRtmpPushUrl = saved?.rtmpPushUrl;
        _savedStreamKey = saved?.streamKey;
        _savedRtspUrl = saved?.rtspUrl;
        _savedMediaMtxRtspUrl = saved?.mediaMtxRtspUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          widget.isEditing ? 'Cámara actualizada' : 'Cámara agregada',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppColors.safeGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      final err = context.read<CameraProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Error al guardar',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.alertRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<CameraProvider>().isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Editar cámara' : 'Agregar cámara',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, fontSize: 18,
              color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name ────────────────────────────────────────────────────
              _SectionHeader('Nombre'),
              const SizedBox(height: 10),
              VsTextField(
                controller: _nameCtrl,
                label: 'Nombre de la cámara',
                hint: 'Ej: Entrada, Jardín, Garaje…',
              ),
              const SizedBox(height: 20),

              // ── Connection mode ─────────────────────────────────────────
              _SectionHeader('Tipo de conexión'),
              const SizedBox(height: 10),
              _ModeCard(
                selected: _streamMode == 'DirectRtsp',
                title: 'IP fija o red local',
                subtitle:
                    'La cámara tiene IP accesible desde tu red local o desde internet.',
                icon: Icons.router_outlined,
                onTap: () => setState(() => _streamMode = 'DirectRtsp'),
              ),
              const SizedBox(height: 10),
              _ModeCard(
                selected: _streamMode == 'RtmpRelay',
                title: 'Sin IP fija (CGNAT / dinámica)',
                subtitle:
                    'Tu proveedor no te da IP fija. Una PC en casa reenvía el video al servidor.',
                icon: Icons.cloud_upload_outlined,
                onTap: () => setState(() => _streamMode = 'RtmpRelay'),
              ),
              const SizedBox(height: 24),

              // ── Camera credentials ──────────────────────────────────────
              _SectionHeader('Acceso a la cámara'),
              const SizedBox(height: 4),
              Text(
                'Datos de tu cámara IP. Los encuentras en su app o manual.',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),

              VsTextField(
                controller: _ipCtrl,
                label: 'Dirección IP',
                hint: 'Ej: 192.168.1.82',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: VsTextField(
                    controller: _portCtrl,
                    label: 'Puerto',
                    hint: '554',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: VsTextField(
                    controller: _pathCtrl,
                    label: 'Ruta (opcional)',
                    hint: '/11  o  /h264/ch1/main/av_stream',
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              VsTextField(
                controller: _userCtrl,
                label: 'Usuario (opcional)',
                hint: 'admin',
              ),
              const SizedBox(height: 12),
              VsTextField(
                controller: _passCtrl,
                label: _hasExistingPassword
                    ? 'Contraseña (vacío = mantener la actual)'
                    : 'Contraseña (opcional)',
                hint: '••••••••',
                isPassword: true,
              ),
              if (_hasExistingPassword) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Checkbox(
                    value: _clearPassword,
                    onChanged: (v) => setState(() => _clearPassword = v!),
                    activeColor: AppColors.alertRed,
                    side: const BorderSide(color: AppColors.textMuted),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _clearPassword = !_clearPassword),
                    child: Text('Borrar contraseña guardada',
                        style: GoogleFonts.inter(
                          color: _clearPassword
                              ? AppColors.alertRed
                              : AppColors.textSecondary,
                          fontSize: 13,
                        )),
                  ),
                ]),
              ],

              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.help_outline,
                text: 'Rutas RTSP frecuentes:\n'
                    '• Número de canal → /11  /12  /1  /2  etc.\n'
                    '• Hikvision → /h264/ch1/main/av_stream\n'
                    '• Dahua → /cam/realmonitor?channel=1&subtype=0\n'
                    '• Reolink → /h264Preview_01_main',
              ),
              const SizedBox(height: 24),

              // ── Set as default ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cámara principal',
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          Text('Se abrirá primero en la pestaña de video.',
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ]),
                  ),
                  Switch(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    activeColor: AppColors.accent,
                    trackColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected)
                            ? AppColors.accent.withAlpha(77)
                            : AppColors.border),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              VsButton(
                label: widget.isEditing ? 'Guardar cambios' : 'Agregar cámara',
                onPressed: isSaving ? null : _save,
                isLoading: isSaving,
              ),

              // ── Post-save: MediaMTX setup instructions ──────────────────
              if (_savedStreamKey != null) ...[
                const SizedBox(height: 28),
                _buildMediaMtxInstructions(),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaMtxInstructions() {
    final isRelay = _streamMode == 'RtmpRelay';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.safeGreen.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.safeGreen.withAlpha(77)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.safeGreen, size: 18),
          const SizedBox(width: 8),
          Text('Cámara configurada',
              style: GoogleFonts.inter(
                  color: AppColors.safeGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ]),
        const SizedBox(height: 10),

        if (!isRelay) ...[
          // DirectRtsp: server pulls automatically — user does nothing else
          Text(
            'El servidor ya está procesando el video de tu cámara. '
            'Abre la pestaña de Video para verlo en directo.',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          if (_savedHlsUrl != null) ...[
            const SizedBox(height: 10),
            Text('URL del stream (solo informativo):',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            _CopyRow(value: _savedHlsUrl!),
          ],
        ] else ...[
          // RtmpRelay: user needs to run FFmpeg on local PC — that's intentional
          Text(
            'Último paso: ejecuta este comando en la PC de tu casa '
            'y déjalo corriendo. El video llegará al servidor automáticamente.',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          if (_savedMediaMtxRtspUrl != null)
            _CopyBox(
              label: 'Comando para tu PC local (FFmpeg):',
              value: 'ffmpeg -rtsp_transport tcp '
                  '-i ${_savedRtspUrl ?? "rtsp://usuario:clave@ip:554/ruta"} '
                  '-c copy -f rtsp -rtsp_transport tcp $_savedMediaMtxRtspUrl',
            ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.info_outline,
            text: 'Déjalo corriendo en una PC de tu casa con acceso a la cámara '
                '(o una app como Termux en un Android viejo). FFmpeg es gratuito: '
                'ffmpeg.org  o  winget install ffmpeg',
          ),
        ],
      ]),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected, required this.title,
    required this.subtitle, required this.icon, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (selected ? AppColors.accent : AppColors.textMuted)
                  .withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: 2),
              color: selected ? AppColors.accent : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.black, size: 13)
                : null,
          ),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withAlpha(51)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.6)),
          ),
        ]),
      );
}

class _CopyRow extends StatelessWidget {
  final String value;
  const _CopyRow({required this.value});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Copiado',
                style: GoogleFonts.inter(color: Colors.white)),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: Text(value,
                  style: GoogleFonts.robotoMono(
                      color: AppColors.accent, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_outlined,
                color: AppColors.textSecondary, size: 16),
          ]),
        ),
      );
}

class _CopyBox extends StatelessWidget {
  final String label, value;
  const _CopyBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 12,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(value,
                style: GoogleFonts.robotoMono(
                    color: AppColors.accent, fontSize: 12, height: 1.6)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Copiado',
                    style: GoogleFonts.inter(color: Colors.white)),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: const Icon(Icons.copy_outlined,
                color: AppColors.textSecondary, size: 18),
          ),
        ]),
      ),
    ]);
  }
}
