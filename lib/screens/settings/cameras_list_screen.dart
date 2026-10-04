import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';
import '../../data/models/camera_config_model.dart';
import '../camera/device_camera_screen.dart';

class CamerasListScreen extends StatefulWidget {
  const CamerasListScreen({super.key});

  @override
  State<CamerasListScreen> createState() => _CamerasListScreenState();
}

class _CamerasListScreenState extends State<CamerasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().fetchCameras();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final isPrimary = context.watch<AuthProvider>().user?.isPrimary ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mis Cámaras',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, fontSize: 18,
                color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (isPrimary)
            TextButton.icon(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add, color: AppColors.accent, size: 20),
              label: Text('Agregar',
                  style: GoogleFonts.inter(
                      color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Builder(builder: (context) {
        if (provider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2));
        }

        if (provider.cameras.isEmpty) {
          return _buildEmpty(context, isPrimary);
        }

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: provider.fetchCameras,
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: provider.cameras.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final cam = provider.cameras[i];
              return _CameraCard(
                cam: cam,
                isPrimary: isPrimary,
                onEdit: isPrimary
                    ? () => cam.isMobileWebRtc
                        ? _openDevice(context, cam)
                        : context.push('/settings/cameras/${cam.id}')
                    : null,
                onZones: isPrimary
                    ? () => context.push('/settings/cameras/${cam.id}/zones')
                    : null,
                onDelete: isPrimary
                    ? () => _confirmDelete(context, cam.id, cam.name)
                    : null,
              );
            },
          ),
        );
      }),
    );
  }

  void _openDevice(BuildContext context, [CameraConfigModel? camera]) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DeviceCameraScreen(camera: camera)));
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.lan_outlined), title: const Text('Agregar cámara IP'),
          onTap: () { Navigator.pop(sheetContext); context.push('/settings/cameras/add'); }),
        ListTile(leading: const Icon(Icons.phone_android), title: const Text('Usar este dispositivo como cámara'),
          onTap: () { Navigator.pop(sheetContext); _openDevice(context); }),
      ]),
    ));
  }

  Widget _buildEmpty(BuildContext context, bool isPrimary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_outlined,
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 20),
          Text('Sin cámaras',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            isPrimary
                ? 'Agrega una cámara IP o usa este dispositivo para monitorear.'
                : 'El residente principal aún no ha configurado cámaras.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          if (isPrimary) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _showAddOptions(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Agregar cámara',
                    style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar cámara',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: Text('¿Eliminar "$name"? Se perderá toda su configuración.',
            style:
                GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style:
                    GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<CameraProvider>().deleteCamera(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Cámara eliminada',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppColors.alertRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            child: Text('Eliminar',
                style: GoogleFonts.inter(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  final CameraConfigModel cam;
  final bool isPrimary;
  final VoidCallback? onEdit;
  final VoidCallback? onZones;
  final VoidCallback? onDelete;

  const _CameraCard({
    required this.cam,
    required this.isPrimary,
    this.onEdit,
    this.onZones,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isConfigured = cam.isConfigured;
    final isDefault = cam.isDefault;
    final name = cam.name;
    final mode = cam.streamMode;
    final ip = cam.cameraIp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault
              ? AppColors.accent.withAlpha(128)
              : AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (isConfigured ? AppColors.accent : AppColors.textMuted)
                .withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isConfigured ? Icons.videocam : Icons.videocam_off_outlined,
            color: isConfigured
                ? AppColors.accent
                : AppColors.textSecondary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accent.withAlpha(77)),
                      ),
                      child: Text('Principal',
                          style: GoogleFonts.inter(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                // Iconos Material (Apache-2.0) en lugar de emojis: se pintan
                // con el color del tema y no dependen de la fuente del sistema.
                _LineaConIcono(
                  icono: isConfigured ? Icons.lan_outlined : Icons.link_off,
                  texto: isConfigured
                      ? (ip ?? 'Configurada')
                      : 'Sin configurar',
                  color: AppColors.textSecondary,
                  tamano: 12,
                ),
                _LineaConIcono(
                  icono: mode == 'RtmpRelay'
                      ? Icons.sync_alt_rounded
                      : Icons.videocam_outlined,
                  texto: cam.isMobileWebRtc ? 'Cámara del dispositivo' : mode == 'RtmpRelay' ? 'Relay RTMP' : 'IP Fija RTSP',
                  color: AppColors.textMuted,
                  tamano: 11,
                ),
                if (isPrimary) Row(children: [
                  const Flexible(child: Text('Notificaciones', style: TextStyle(fontSize: 11))),
                  Switch(value: cam.notificationsEnabled,
                    onChanged: context.watch<CameraProvider>().isSaving ? null : (enabled) async {
                      final provider = context.read<CameraProvider>();
                      final ok = await provider.setNotificationsEnabled(cam.id, enabled);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(provider.error ?? 'No se pudo guardar el cambio.')));
                      }
                    }),
                ]),
              ]),
        ),
        if (isPrimary) ...[
          IconButton(
            icon: const Icon(Icons.crop_free,
                color: AppColors.accent, size: 18),
            onPressed: onZones,
            tooltip: 'Zonas de interés',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 18),
            onPressed: onEdit,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.alertRed, size: 18),
            onPressed: onDelete,
            tooltip: 'Eliminar',
          ),
        ],
      ]),
    );
  }
}

/// Una linea de texto precedida por un icono, alineados por su centro.
class _LineaConIcono extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  final double tamano;
  const _LineaConIcono({
    required this.icono,
    required this.texto,
    required this.color,
    required this.tamano,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icono, size: tamano + 2, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(texto,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: color, fontSize: tamano)),
        ),
      ]);
}
