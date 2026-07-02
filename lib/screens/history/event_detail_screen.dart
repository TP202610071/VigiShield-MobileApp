import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/security_event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_settings_provider.dart';
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
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.deleteEvent,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(l10n.deleteEventConfirm,
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: GoogleFonts.inter(color: AppColors.alertRed)),
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
        title: Text(context.l10n.eventDetail),
        actions: [
          if (!_loading && _event != null &&
              context.read<DevSettingsProvider>().isPrimaryEffective(context.read<AuthProvider>().user))
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
                  child: Text(context.l10n.eventNotFound,
                      style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final ev = _event!;
    final l10n = context.l10n;
    final color = EventCard.colorFor(ev.eventType);
    final icon = EventCard.iconFor(ev.eventType);
    final label = l10n.eventTypeLabel(ev.eventType);

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
                  DateFormat(l10n.dateFormatFull, l10n.localeCode)
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
                        Text(l10n.nightActivity,
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
            title: l10n.details,
            rows: [
              if (ev.personName != null)
                _Row(label: l10n.person, value: ev.personName!),
              _Row(
                label: l10n.riskLevel,
                value: l10n.riskLabel(ev.riskLevel),
                valueColor: _riskColor(ev.riskLevel),
              ),
              if (ev.confidenceScore != null)
                _Row(
                  label: l10n.confidence,
                  value: '${(ev.confidenceScore! * 100).toStringAsFixed(1)}%',
                ),
              _Row(label: l10n.eventType, value: l10n.eventTypeLabel(ev.eventType)),
            ],
          ),
          if (ev.imageCapturePath != null) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: l10n.imageCapture,
              rows: const [],
              child: _EventPhoto(url: ev.imageCapturePath!),
            ),
          ],
          if (ev.videoClipPath != null) ...[
            const SizedBox(height: 16),
            _DetailSection(
              title: l10n.videoClip,
              rows: const [],
              child: _ClipSection(url: ev.videoClipPath!),
            ),
          ],
        ],
      ),
    );
  }

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

/// Inline player for the event's recorded clip (R2-hosted MP4).
class _ClipSection extends StatefulWidget {
  final String url;
  const _ClipSection({required this.url});

  @override
  State<_ClipSection> createState() => _ClipSectionState();
}

class _ClipSectionState extends State<_ClipSection> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.open(Media(widget.url), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: _controller, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MediaActionButton(
              icon: Icons.fullscreen,
              label: context.l10n.fullscreen,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _FullScreenVideo(url: widget.url))),
            ),
            _MediaActionButton(
              icon: Icons.download_outlined,
              label: context.l10n.save,
              onTap: () => _MediaActions.save(context, widget.url, isVideo: true),
            ),
            _MediaActionButton(
              icon: Icons.share_outlined,
              label: context.l10n.share,
              onTap: () => _MediaActions.share(context, widget.url),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Event photo (tap → fullscreen, save, share) ───────────────────────────────

class _EventPhoto extends StatelessWidget {
  final String url;
  const _EventPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _FullScreenImage(url: url))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, prog) => prog == null
                      ? child
                      : Container(
                          height: 200,
                          alignment: Alignment.center,
                          color: AppColors.surface,
                          child: const CircularProgressIndicator(
                              color: AppColors.accent, strokeWidth: 2),
                        ),
                  errorBuilder: (c, e, s) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textMuted, size: 40),
                        const SizedBox(height: 8),
                        Text(context.l10n.imageUnavailable,
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
                // Expand hint
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MediaActionButton(
              icon: Icons.download_outlined,
              label: context.l10n.save,
              onTap: () => _MediaActions.save(context, url, isVideo: false),
            ),
            _MediaActionButton(
              icon: Icons.share_outlined,
              label: context.l10n.share,
              onTap: () => _MediaActions.share(context, url),
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: AppColors.accent),
      label: Text(label,
          style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13)),
    );
  }
}

// ── Fullscreen viewers ────────────────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => _MediaActions.save(context, url, isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () => _MediaActions.share(context, url),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(child: Image.network(url)),
      ),
    );
  }
}

class _FullScreenVideo extends StatefulWidget {
  final String url;
  const _FullScreenVideo({required this.url});

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.open(Media(widget.url), play: true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => _MediaActions.save(context, widget.url, isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () => _MediaActions.share(context, widget.url),
          ),
        ],
      ),
      body: Center(child: Video(controller: _controller, fit: BoxFit.contain)),
    );
  }
}

// ── Download / save-to-gallery / share helpers ────────────────────────────────

class _MediaActions {
  static Future<String?> _downloadToTemp(String url) async {
    final dir = await getTemporaryDirectory();
    var name = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : 'vigishield_media';
    if (!name.contains('.')) name = '$name.bin';
    final path = '${dir.path}/$name';
    await Dio().download(url, path);
    return path;
  }

  static Future<void> save(BuildContext context, String url,
      {required bool isVideo}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await _downloadToTemp(url);
      if (path == null) throw Exception('download failed');
      if (isVideo) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedToGallery)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  static Future<void> share(BuildContext context, String url) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await _downloadToTemp(url);
      if (path == null) throw Exception('download failed');
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }
}
