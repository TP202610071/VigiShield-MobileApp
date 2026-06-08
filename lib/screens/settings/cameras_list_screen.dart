import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';

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
              onPressed: () => context.push('/settings/cameras/add'),
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
                    ? () => context.push('/settings/cameras/${cam.id}')
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
                ? 'Agrega tu primera cámara IP para comenzar a monitorear.'
                : 'El residente principal aún no ha configurado cámaras.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          if (isPrimary) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.push('/settings/cameras/add'),
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
  final dynamic cam;
  final bool isPrimary;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CameraCard({
    required this.cam,
    required this.isPrimary,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isConfigured = cam.isConfigured as bool;
    final isDefault = cam.isDefault as bool;
    final name = cam.name as String;
    final mode = cam.streamMode as String;
    final ip = cam.cameraIp as String?;

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
                Text(
                  isConfigured
                      ? (ip != null ? '📡 $ip' : 'Configurada')
                      : 'Sin configurar',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                Text(
                  mode == 'RtmpRelay' ? '🔁 Relay RTMP' : '📺 IP Fija RTSP',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ]),
        ),
        if (isPrimary) ...[
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
