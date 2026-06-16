import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../data/models/security_event_model.dart';

class EventCard extends StatelessWidget {
  final SecurityEventModel event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  static Color colorFor(String type) => switch (type) {
        'FaceRecognized' => AppColors.safeGreen,
        'LowConfidenceFace' || 'Tailgating' || 'Arrest' => AppColors.warningAmber,
        _ => AppColors.alertRed,
      };

  static IconData iconFor(String type) => switch (type) {
        // Face recognition
        'FaceRecognized' => Icons.face_outlined,
        'UnknownFace' => Icons.person_off_outlined,
        'LowConfidenceFace' => Icons.help_outline,
        'RecurrentUnknownFace' => Icons.warning_amber_outlined,
        // Access & intrusion
        'ForcedAccessAttempt' => Icons.lock_open_outlined,
        'LockpickingAttempt' => Icons.key_off_outlined,
        'Tailgating' => Icons.directions_walk,
        'Climbing' => Icons.north,
        'Burglary' => Icons.home_work_outlined,
        // Physical
        'PhysicalAggression' => Icons.sports_mma,
        'Assault' || 'Abuse' => Icons.personal_injury_outlined,
        'Arrest' => Icons.gavel_outlined,
        // Property crime
        'Stealing' || 'Shoplifting' || 'Robbery' => Icons.shopping_bag_outlined,
        'Vandalism' => Icons.broken_image_outlined,
        'Arson' => Icons.local_fire_department_outlined,
        // Hazard
        'Explosion' => Icons.bolt_outlined,
        'Roadaccidents' => Icons.car_crash_outlined,
        // Object detection
        'WeaponDetected' => Icons.gpp_bad_outlined,
        _ => Icons.notifications_outlined,
      };

  String _relativeTime(AppStrings l10n) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(event.createdAt.toUtc());
    if (diff.inSeconds < 60) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    return DateFormat(l10n.dateFormatShort, l10n.localeCode)
        .format(event.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = colorFor(event.eventType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconFor(event.eventType), color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.eventTypeLabel(event.eventType),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    _relativeTime(l10n),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (event.isNighttime) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.nightlight_round, size: 11, color: AppColors.warningAmber),
                                  ],
                                ],
                              ),
                              if (event.personName != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  event.personName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (event.cameraName != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.videocam_outlined, size: 10, color: AppColors.textMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                      event.cameraName!,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RiskBadge(riskLevel: event.riskLevel),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String riskLevel;

  const _RiskBadge({required this.riskLevel});

  Color get _color => switch (riskLevel) {
        'None' => AppColors.textMuted,
        'Low' => AppColors.safeGreen,
        'Medium' => AppColors.warningAmber,
        'High' || 'Critical' => AppColors.alertRed,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    if (riskLevel == 'None') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        context.l10n.riskLabel(riskLevel),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
