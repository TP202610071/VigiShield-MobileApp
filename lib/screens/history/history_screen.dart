import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/camera_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/event_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollCtrl = ScrollController();

  /// Tipos que el sistema puede llegar a registrar hoy: los cuatro que produce el
  /// motor de IA más los que la herramienta de pruebas puede disparar. Faltaba
  /// "Riesgo de intrusión", que sí se genera y no había forma de filtrarlo.
  static const _filterValues = <String?>[
    null, 'FaceRecognized', 'UnknownFace', 'Tailgating', 'SuspiciousIntent',
    'WeaponDetected', 'Climbing', 'PhysicalAggression',
  ];

  /// El nombre sale del vocabulario canónico (el mismo del historial y de las
  /// alertas de WhatsApp) en vez de una lista aparte que puede desincronizarse.
  String _filterLabel(AppStrings l10n, String? v) =>
      v == null ? l10n.filterAll : l10n.eventTypeLabel(v);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchEvents(refresh: true);
      // Las cámaras alimentan la fila de filtros; si aún no se consultaron
      // (p. ej. se entra al historial antes que a la pestaña de video) se piden.
      final cams = context.read<CameraProvider>();
      if (cams.cameras.isEmpty) cams.fetchCameras();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  /// Cambia UN filtro conservando el otro.
  void _apply(EventProvider p, {String? type, String? cameraId, bool keepType = true,
      bool keepCamera = true}) {
    p.fetchEvents(
      type: keepType ? (type ?? p.activeFilter) : type,
      cameraId: keepCamera ? (cameraId ?? p.activeCameraId) : cameraId,
      refresh: true,
    );
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<EventProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventProvider>();
    final cameras = context.watch<CameraProvider>().cameras;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                l10n.history,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Fila 1 — filtro por tipo de evento.
            _ChipRow(
              options: [
                for (final v in _filterValues) (v, _filterLabel(l10n, v)),
              ],
              selected: provider.activeFilter,
              onSelect: (v) => _apply(provider, type: v, keepType: false),
            ),
            // Fila 2 — filtro por cámara. Solo aparece si el hogar tiene más de
            // una: con una sola cámara el filtro no distingue nada.
            if (cameras.length > 1) ...[
              const SizedBox(height: 8),
              _ChipRow(
                icon: Icons.videocam_outlined,
                options: [
                  (null, l10n.filterAllCameras),
                  for (final c in cameras) (c.id, c.name),
                ],
                selected: provider.activeCameraId,
                onSelect: (v) => _apply(provider, cameraId: v, keepCamera: false),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                  : provider.error != null && provider.events.isEmpty
                      ? _ErrorView(
                          message: provider.error!,
                          onRetry: () => provider.fetchEvents(
                            refresh: true,
                            type: provider.activeFilter,
                            cameraId: provider.activeCameraId,
                          ),
                        )
                      : provider.events.isEmpty
                          ? _EmptyView()
                          : RefreshIndicator(
                              onRefresh: () => provider.fetchEvents(
                                refresh: true,
                                type: provider.activeFilter,
                                cameraId: provider.activeCameraId,
                              ),
                              color: AppColors.accent,
                              backgroundColor: AppColors.surface,
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                itemCount: provider.events.length + (provider.isLoadingMore ? 1 : 0),
                                itemBuilder: (context, i) {
                                  if (i >= provider.events.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.accent, strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  final event = provider.events[i];
                                  return EventCard(
                                    event: event,
                                    onTap: () => context.push('/history/${event.id}'),
                                  );
                                },
                              ),
                            ),
            ),
            if (provider.error != null && provider.events.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(provider.error!)),
                    TextButton(
                      onPressed: provider.isLoadingMore ? null : provider.loadMore,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal de fichas de filtro. La usan el filtro por tipo de evento y
/// el filtro por cámara, para que ambos se vean y se comporten igual.
class _ChipRow extends StatelessWidget {
  final List<(String?, String)> options;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final IconData? icon;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = options[i];
          final isActive = selected == value;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null && value != null) ...[
                    Icon(icon,
                        size: 14,
                        color: isActive ? Colors.black : AppColors.textSecondary),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? Colors.black : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            context.l10n.noEventsLogged,
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.eventsWillAppear,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: AppColors.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent),
              ),
              child: Text(context.l10n.retry,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.accent)),
            ),
          ),
        ],
      ),
    );
  }
}
