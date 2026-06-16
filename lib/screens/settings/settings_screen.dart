import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_settings_provider.dart';
import '../../providers/system_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Tap the version row this many times to reveal the hidden developer tools
  // (Android-style). Only actually opens for real Admin accounts.
  int _versionTaps = 0;

  void _onVersionTap() {
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    setState(() => _versionTaps++);
    if (_versionTaps >= 7) {
      _versionTaps = 0;
      if (isAdmin) {
        context.push('/settings/developer');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.developerOptions,
              style: GoogleFonts.inter(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final dev = context.watch<DevSettingsProvider>();
    final user = auth.user;
    final isPrimary = dev.isPrimaryEffective(user);
    // Always reachable for a real admin — even while previewing a role — so the
    // developer can switch the role back and never gets locked out of the tools.
    final showDevTile = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                l10n.settings,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Profile card → opens the profile screen
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const UserAvatar(size: 52, fontSize: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            _RoleChip(role: user?.role ?? 'Secondary'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _SectionLabel(l10n.sectionAccount),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.lock_outline,
                label: l10n.changePassword,
                onTap: () => _showChangePasswordDialog(context),
              ),
              const SizedBox(height: 24),

              if (isPrimary) ...[
                _SectionLabel(l10n.sectionSystem),
                const SizedBox(height: 8),
                _AlertConfigTile(),
                const SizedBox(height: 16),
                _SettingsTile(
                  icon: Icons.videocam_outlined,
                  label: l10n.myCameras,
                  onTap: () => context.push('/settings/cameras'),
                ),
                const SizedBox(height: 16),
                _SettingsTile(
                  icon: Icons.face_outlined,
                  label: l10n.authorizedFaces,
                  onTap: () => context.push('/settings/faces'),
                ),
                const SizedBox(height: 24),
              ],

              _SectionLabel(l10n.sectionPreferences),
              const SizedBox(height: 8),
              _LanguageTile(),
              const SizedBox(height: 24),

              if (showDevTile) ...[
                _SectionLabel(l10n.sectionDeveloper),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.code,
                  label: l10n.developerTools,
                  onTap: () => context.push('/settings/developer'),
                ),
                const SizedBox(height: 24),
              ],

              _SectionLabel(l10n.sectionAbout),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _onVersionTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VigiShield',
                                style: GoogleFonts.inter(
                                    fontSize: 14, color: AppColors.textPrimary)),
                            Text(l10n.version(AppConstants.appVersion),
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              VsButton(
                label: l10n.logout,
                variant: VsButtonVariant.danger,
                width: double.infinity,
                icon: Icons.logout,
                onPressed: () => _showLogoutDialog(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.logout,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(l10n.logoutConfirm,
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: Text(l10n.logout,
                style: GoogleFonts.inter(color: AppColors.alertRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final l10n = context.l10n;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 28,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.changePassword,
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              VsTextField(
                label: l10n.currentPassword,
                controller: currentCtrl,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (v) => (v?.isEmpty ?? true) ? l10n.requiredField : null,
              ),
              const SizedBox(height: 16),
              VsTextField(
                label: l10n.newPassword,
                controller: newCtrl,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) => (v?.length ?? 0) < 8 ? l10n.passwordMin : null,
              ),
              const SizedBox(height: 24),
              VsButton(
                label: l10n.saveChanges,
                width: double.infinity,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final ok = await context.read<AuthProvider>()
                      .changePassword(currentCtrl.text, newCtrl.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        ok ? l10n.passwordUpdated : (context.read<AuthProvider>().errorMessage ?? l10n.error),
                      ),
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'Admin';
    final isPrimary = role == 'Primary' || isAdmin;
    final color = isAdmin
        ? AppColors.warningAmber
        : (isPrimary ? AppColors.accent : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        context.l10n.roleLabel(role),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 1),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Language switcher ─────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<LocaleProvider>();
    final current = provider.isEnglish ? l10n.english : l10n.spanish;

    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.translate, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l10n.language,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
          ),
          Text(current, style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  void _show(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.read<LocaleProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          _LangOption(
            label: l10n.spanish, flag: '🇪🇸',
            selected: !provider.isEnglish,
            onTap: () { provider.setLocale(AppLocale.es); Navigator.pop(ctx); },
          ),
          _LangOption(
            label: l10n.english, flag: '🇬🇧',
            selected: provider.isEnglish,
            onTap: () { provider.setLocale(AppLocale.en); Navigator.pop(ctx); },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({
    required this.label, required this.flag,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary)),
      trailing: selected ? const Icon(Icons.check, color: AppColors.accent) : null,
      onTap: onTap,
    );
  }
}

// ── Alert config ──────────────────────────────────────────────────────────────

class _AlertConfigTile extends StatefulWidget {
  @override
  State<_AlertConfigTile> createState() => _AlertConfigTileState();
}

class _AlertConfigTileState extends State<_AlertConfigTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemProvider>().fetchAlertConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = context.watch<SystemProvider>().alertConfig;

    return GestureDetector(
      onTap: config != null ? () => _showAlertConfig(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.configureAlerts,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            ),
            if (config == null)
              const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            else
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showAlertConfig(BuildContext context) {
    final l10n = context.l10n;
    final config = context.read<SystemProvider>().alertConfig!;
    var draft = config;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 28,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.configureAlerts,
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _SwitchRow(l10n.alertUnknownPerson, draft.unknownPersonEnabled,
                  (v) => setS(() => draft = draft.copyWith(unknownPersonEnabled: v))),
              _SwitchRow(l10n.alertForcedAccess, draft.forcedAccessEnabled,
                  (v) => setS(() => draft = draft.copyWith(forcedAccessEnabled: v))),
              _SwitchRow(l10n.alertLoiterer, draft.tailgatingEnabled,
                  (v) => setS(() => draft = draft.copyWith(tailgatingEnabled: v))),
              _SwitchRow(l10n.alertClimbing, draft.climbingEnabled,
                  (v) => setS(() => draft = draft.copyWith(climbingEnabled: v))),
              _SwitchRow(l10n.alertAggression, draft.aggressionEnabled,
                  (v) => setS(() => draft = draft.copyWith(aggressionEnabled: v))),
              const SizedBox(height: 20),
              VsButton(
                label: l10n.save,
                width: double.infinity,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<SystemProvider>().updateAlertConfig(draft);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.accent.withOpacity(0.3)
                    : AppColors.border),
          ),
        ],
      ),
    );
  }
}
