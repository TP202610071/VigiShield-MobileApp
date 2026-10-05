import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/camera_provider.dart';
import '../../data/models/camera_config_model.dart';
import '../camera/device_camera_screen.dart';
import '../../data/services/mobile_camera_publisher.dart';

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

        if (provider.misCamaras.isEmpty) {
          return _buildEmpty(context, isPrimary);
        }

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: provider.fetchCameras,
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: provider.misCamaras.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final cam = provider.misCamaras[i];
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

  Future<void> _openDevice(BuildContext context, [CameraConfigModel? camera]) async {
    final transmitiendo = await Navigator.of(context).push(MaterialPageRoute<bool>(
      builder: (_) => DeviceCameraScreen(camera: camera)));
    if (transmitiendo != true || !context.mounted) return;
    // Recién empezó a transmitir: lo siguiente es dibujar las zonas de
    // interés. El editor explica para qué sirven.
    final id = context.read<MobileCameraPublisher>().cameraId;
    if (id != null) await context.push('/settings/cameras/$id/zones?intro=1');
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
              // Si la cámara es este mismo teléfono transmitiendo, se corta
              // antes: si no, seguiría enviando video de una cámara borrada.
              final publicador = context.read<MobileCameraPublisher>();
              if (publicador.cameraId == id &&
                  (publicador.isPublishing || publicador.isStarting)) {
                await publicador.stop();
              }
              if (!context.mounted) return;
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
    final saving = context.watch<CameraProvider>().isSaving;

    return LayoutBuilder(builder: (context, constraints) {
      final showInlineActions = constraints.maxWidth >= 300;
      return Container(
      key: ValueKey('camera-card-${cam.id}'),
      padding: const EdgeInsets.all(12),
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
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: (isConfigured ? AppColors.accent : AppColors.textMuted)
                .withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            // La cámara del teléfono se distingue de un vistazo: no es una
            // cámara IP y no se configura igual.
            cam.isMobileWebRtc
                ? Icons.phone_android
                : isConfigured
                    ? Icons.videocam
                    : Icons.videocam_off_outlined,
            color: isConfigured
                ? AppColors.accent
                : AppColors.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
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
                //
                // Una cámara de teléfono no tiene IP, así que mostrar
                // "Configurada" no decía nada: se indica de dónde sale el video.
                if (!cam.isActive)
                  const _LineaConIcono(
                    icono: Icons.pause_circle_outline,
                    texto: 'Desactivada: no se analiza',
                    color: AppColors.warningAmber,
                    tamano: 12,
                  )
                else if (cam.isMobileWebRtc)
                  const _LineaConIcono(
                    icono: Icons.phone_android,
                    texto: 'Cámara de este teléfono',
                    color: AppColors.textSecondary,
                    tamano: 12,
                  )
                else ...[
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
                    texto: mode == 'RtmpRelay' ? 'Relay RTMP' : 'IP Fija RTSP',
                    color: AppColors.textMuted,
                    tamano: 11,
                  ),
                ],
                // Desactivar una camara es lo unico que ahorra recursos de
                // verdad: el motor analiza cada camara configurada la vea
                // alguien o no, y eso cuesta ~80% de un nucleo por camara.
                if (isPrimary) Wrap(spacing: 8, runSpacing: 0, children: [
                  _CompactSwitch(label: 'Activa', value: cam.isActive,
                    onChanged: saving ? null : (activa) async {
                      final provider = context.read<CameraProvider>();
                      final ok = await provider.setActive(cam.id, activa);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(provider.error ?? 'No se pudo guardar el cambio.')));
                      }
                    }),
                  _CompactSwitch(label: 'Notificaciones', value: cam.notificationsEnabled,
                    onChanged: saving ? null : (enabled) async {
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
        if (isPrimary && showInlineActions) ...[
          _CardAction(icon: Icons.crop_free, tooltip: 'Zonas de interés', onTap: onZones),
          _CardAction(icon: Icons.edit_outlined, tooltip: 'Editar', onTap: onEdit),
          _CardAction(icon: Icons.delete_outline, tooltip: 'Eliminar',
              color: AppColors.alertRed, onTap: onDelete),
        ] else if (isPrimary)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Opciones de la cámara',
            color: AppColors.surfaceElevated,
            onSelected: (opcion) {
              switch (opcion) {
                case 'zonas':
                  onZones?.call();
                case 'editar':
                  onEdit?.call();
                case 'eliminar':
                  onDelete?.call();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'zonas',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.crop_free, color: AppColors.accent, size: 18),
                  title: Text('Zonas de interés'),
                ),
              ),
              const PopupMenuItem(
                value: 'editar',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined,
                      color: AppColors.textSecondary, size: 18),
                  title: Text('Editar'),
                ),
              ),
              const PopupMenuItem(
                value: 'eliminar',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline,
                      color: AppColors.alertRed, size: 18),
                  title: Text('Eliminar'),
                ),
              ),
            ],
          ),
      ]),
    );
    });
  }
}

class _CompactSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _CompactSwitch({required this.label, required this.value, this.onChanged});
  @override Widget build(BuildContext context) => SizedBox(height: 30,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      SizedBox(width: 36, height: 28, child: Transform.scale(
        scale: 0.68, child: Switch(value: value, onChanged: onChanged))),
    ]));
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;
  const _CardAction({required this.icon, required this.tooltip,
    required this.onTap, this.color = AppColors.textSecondary});
  @override Widget build(BuildContext context) => IconButton(
    tooltip: tooltip, onPressed: onTap,
    icon: Icon(icon, color: color, size: 18), padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 30, height: 34));
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
