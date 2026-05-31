import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../data/models/security_event_model.dart';

class EventCard extends StatelessWidget {
  final SecurityEventModel event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  static String labelFor(String type) => switch (type) {
        'FaceRecognized' => 'Acceso reconocido',
        'UnknownFace' => 'Persona desconocida',
        'LowConfidenceFace' => 'Detección baja confianza',
        'RecurrentUnknownFace' => 'Visitante desconocido recurrente',
        'ForcedAccessAttempt' => 'Intento de acceso forzado',
        'LockpickingAttempt' => 'Intento de ganzúa detectado',
        'Tailgating' => 'Merodeador detectado',
        'Climbing' => 'Escalamiento detectado',
        'PhysicalAggression' => 'Agresión física detectada',
        _ => type,
      };

  static Color colorFor(String type) => switch (type) {
        'FaceRecognized' => AppColors.safeGreen,
        'LowConfidenceFace' || 'Tailgating' => AppColors.warningAmber,
        _ => AppColors.alertRed,
      };

  static IconData iconFor(String type) => switch (type) {
        'FaceRecognized' => Icons.face_outlined,
        'UnknownFace' => Icons.person_off_outlined,
        'LowConfidenceFace' => Icons.help_outline,
        'RecurrentUnknownFace' => Icons.warning_amber_outlined,
        'ForcedAccessAttempt' => Icons.lock_open_outlined,
        'LockpickingAttempt' => Icons.key_off_outlined,
        'Tailgating' => Icons.directions_walk,
        'Climbing' => Icons.north,
        'PhysicalAggression' => Icons.sports_mma,
        _ => Icons.notifications_outlined,
      };

  String _relativeTime() {
    final now = DateTime.now().toUtc();
    final diff = now.difference(event.createdAt.toUtc());
    if (diff.inSeconds < 60) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return DateFormat('d MMM, HH:mm', 'es').format(event.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
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
                                labelFor(event.eventType),
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
                                    _relativeTime(),
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

  String get _label => switch (riskLevel) {
        'None' => '',
        'Low' => 'Bajo',
        'Medium' => 'Medio',
        'High' => 'Alto',
        'Critical' => 'Crítico',
        _ => '',
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
        _label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
