import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: Text(l10n.fromGallery,
                  style: GoogleFonts.inter(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: Text(l10n.fromCamera,
                  style: GoogleFonts.inter(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    final ok = await context.read<AuthProvider>().uploadAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _uploading = false);
    _snack(ok ? l10n.photoUpdated : (context.read<AuthProvider>().errorMessage ?? l10n.photoError),
        ok);
  }

  void _editInfo() {
    final l10n = context.l10n;
    final user = context.read<AuthProvider>().user;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final waCtrl = TextEditingController(text: user?.whatsAppNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 28,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.editProfile,
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              VsTextField(
                controller: nameCtrl,
                label: l10n.fullName,
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? l10n.requiredField : null,
              ),
              const SizedBox(height: 16),
              VsTextField(
                controller: waCtrl,
                label: l10n.whatsappLabel,
                hint: '+52 …',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              VsButton(
                label: l10n.saveChanges,
                width: double.infinity,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final ok = await context.read<AuthProvider>().updateProfile(
                        name: nameCtrl.text.trim(),
                        whatsAppNumber:
                            waCtrl.text.trim().isEmpty ? null : waCtrl.text.trim(),
                      );
                  if (mounted) {
                    _snack(
                        ok ? l10n.profileUpdated : (context.read<AuthProvider>().errorMessage ?? l10n.error),
                        ok);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: ok ? AppColors.safeGreen : AppColors.alertRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editProfile,
            onPressed: _editInfo,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _uploading ? null : _changePhoto,
              child: Stack(
                children: [
                  const UserAvatar(size: 104, fontSize: 40),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: _uploading
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.photo_camera, size: 14, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              user?.name ?? '',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: _changePhoto,
              child: Text(l10n.changePhoto,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _RoleBadge(role: user?.role ?? 'Secondary')),
          const SizedBox(height: 28),
          _InfoTile(icon: Icons.email_outlined, label: l10n.email, value: user?.email ?? '—'),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.shield_outlined,
            label: l10n.role,
            value: l10n.roleLabel(user?.role ?? 'Secondary'),
          ),
          if ((user?.whatsAppNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoTile(
                icon: Icons.chat_outlined, label: l10n.whatsapp, value: user!.whatsAppNumber!),
          ],
          if (user != null) ...[
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: l10n.memberSince(''),
              value: DateFormat(l10n.dateFormatLong, l10n.localeCode)
                  .format(user.createdAt.toLocal()),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'Admin';
    final isPrimary = role == 'Primary' || isAdmin;
    final color = isAdmin
        ? AppColors.warningAmber
        : (isPrimary ? AppColors.accent : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdmin ? Icons.code : Icons.verified_user_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            context.l10n.roleLabel(role),
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
