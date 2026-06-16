import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_settings_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/system_provider.dart';
import '../../widgets/event_card.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/vs_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<SystemProvider>().fetchStatus(),
      context.read<EventProvider>().fetchEvents(refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final system = context.watch<SystemProvider>();
    final events = context.watch<EventProvider>();
    final user = auth.user;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              floating: true,
              snap: true,
              elevation: 0,
              // Force left-aligned on every platform (iOS centres single-line
              // titles by default, which made "Hola, …" jump to the centre).
              centerTitle: false,
              titleSpacing: 20,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.greeting(user?.name.split(' ').first ?? ''),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat(l10n.dateFormatLong, l10n.localeCode)
                        .format(DateTime.now()),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const UserAvatar(size: 36, fontSize: 14),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  _StatusCard(system: system),
                  const SizedBox(height: 16),
                  _StatsRow(system: system),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.recentEvents,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/history'),
                        child: Text(
                          l10n.seeAll,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (events.isLoading)
                    const _EventsShimmer()
                  else if (events.events.isEmpty)
                    _EmptyEvents()
                  else
                    ...events.events
                        .take(5)
                        .map((e) => EventCard(event: e)),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatefulWidget {
  final SystemProvider system;

  const _StatusCard({required this.system});

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.system.status;
    final isActive = status?.isMonitoringActive ?? true;
    final statusColor = isActive ? AppColors.safeGreen : AppColors.warningAmber;
    final l10n = context.l10n;
    final user = context.read<AuthProvider>().user;
    final canControl = context.watch<DevSettingsProvider>().isPrimaryEffective(user);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.06 * _pulse.value),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.15),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Icon(
                    isActive ? Icons.shield : Icons.shield_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? l10n.systemActive : l10n.systemPaused,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? l10n.monitoringRealtime : l10n.monitoringStopped,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (canControl)
            widget.system.isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  )
                : VsButton(
                    label: isActive ? l10n.pause : l10n.resume,
                    variant: isActive ? VsButtonVariant.secondary : VsButtonVariant.primary,
                    onPressed: () async {
                      final sp = context.read<SystemProvider>();
                      if (isActive) {
                        await sp.pauseMonitoring();
                      } else {
                        await sp.resumeMonitoring();
                      }
                    },
                    width: 90,
                  ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final SystemProvider system;

  const _StatsRow({required this.system});

  @override
  Widget build(BuildContext context) {
    final status = system.status;
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.event_note_outlined,
            value: status?.eventsTodayCount.toString() ?? '—',
            label: l10n.eventsToday,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.access_time,
            value: status?.lastEventAt != null
                ? DateFormat('HH:mm').format(status!.lastEventAt!.toLocal())
                : '—',
            label: l10n.lastEvent,
            color: AppColors.warningAmber,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EventsShimmer extends StatelessWidget {
  const _EventsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.safeGreen, size: 48),
          const SizedBox(height: 12),
          Text(
            context.l10n.noRecentEvents,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.homeSafe,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
