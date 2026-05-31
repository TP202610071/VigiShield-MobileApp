import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/security_event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/event_card.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  SecurityEventModel? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ev = await context.read<EventProvider>().getById(widget.eventId);
    if (mounted) setState(() { _event = ev; _loading = false; });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar evento',
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('¿Estás seguro de que deseas eliminar este evento?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: GoogleFonts.inter(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<EventProvider>().deleteEvent(widget.eventId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del evento'),
        actions: [
          if (!_loading && _event != null && (context.read<AuthProvider>().user?.isPrimary ?? false))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.alertRed),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : _event == null
              ? Center(
                  child: Text('Evento no encontrado',
                      style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final ev = _event!;
    final color = EventCard.colorFor(ev.eventType);
    final icon = EventCard.iconFor(ev.eventType);
    final label = EventCard.labelFor(ev.eventType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat("d 'de' MMMM, yyyy · HH:mm:ss", 'es')
                      .format(ev.createdAt.toLocal()),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (ev.isNighttime) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warningAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nightlight_round,
                            size: 14, color: AppColors.warningAmber),
                        const SizedBox(width: 6),
                        Text('Actividad nocturna',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.warningAmber)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Detalles',
            rows: [
              if (ev.personName != null)
                _Row(label: 'Persona', value: ev.personName!),
              _Row(
                label: 'Nivel de riesgo',
                value: _riskLabel(ev.riskLevel),
                valueColor: _riskColor(ev.riskLevel),
              ),
              if (ev.confidenceScore != null)
                _Row(
                  label: 'Confianza',
                  value: '${(ev.confidenceScore! * 100).toStringAsFixed(1)}%',
                ),
              _Row(label: 'Tipo de evento', value: ev.eventType),
            ],
          ),
          if (ev.imageCapturePath != null) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Captura de imagen',
              rows: const [],
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textMuted, size: 40),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _riskLabel(String risk) => switch (risk) {
        'None' => 'Ninguno',
        'Low' => 'Bajo',
        'Medium' => 'Medio',
        'High' => 'Alto',
        'Critical' => 'Crítico',
        _ => risk,
      };

  Color _riskColor(String risk) => switch (risk) {
        'None' => AppColors.textSecondary,
        'Low' => AppColors.safeGreen,
        'Medium' => AppColors.warningAmber,
        'High' || 'Critical' => AppColors.alertRed,
        _ => AppColors.textSecondary,
      };
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  final Widget? child;

  const _DetailSection({required this.title, required this.rows, this.child});

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
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 0.8),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...rows.map((r) => _buildRow(r)),
          ],
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_Row r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(r.label,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          Text(r.value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: r.valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({required this.label, required this.value, this.valueColor});
}
