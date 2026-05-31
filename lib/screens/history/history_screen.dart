import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/event_provider.dart';
import '../../widgets/event_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollCtrl = ScrollController();

  static const _filters = [
    (label: 'Todos', value: null),
    (label: 'Reconocidos', value: 'FaceRecognized'),
    (label: 'Desconocidos', value: 'UnknownFace'),
    (label: 'Merodeadores', value: 'Tailgating'),
    (label: 'Acceso forzado', value: 'ForcedAccessAttempt'),
    (label: 'Agresión', value: 'PhysicalAggression'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchEvents(refresh: true);
    });
    _scrollCtrl.addListener(_onScroll);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Historial',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final isActive = provider.activeFilter == f.value;
                  return GestureDetector(
                    onTap: () => provider.fetchEvents(type: f.value, refresh: true),
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
                      child: Center(
                        child: Text(
                          f.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? Colors.black : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                  : provider.error != null
                      ? _ErrorView(message: provider.error!, onRetry: () => provider.fetchEvents(refresh: true))
                      : provider.events.isEmpty
                          ? _EmptyView()
                          : RefreshIndicator(
                              onRefresh: () => provider.fetchEvents(refresh: true),
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
          ],
        ),
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
            'Sin eventos registrados',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Los eventos detectados aparecerán aquí',
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
              child: Text('Reintentar',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.accent)),
            ),
          ),
        ],
      ),
    );
  }
}
