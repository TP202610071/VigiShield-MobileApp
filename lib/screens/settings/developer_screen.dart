import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_settings_provider.dart';
import '../../providers/server_config_provider.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

/// Hidden, admin-only developer tools. Reached by tapping the app version 7×
/// in Settings → About. Lets a developer preview other roles for demos, point
/// the app at a different backend, and manage who else is an administrator.
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  List<AdminUser>? _admins;
  bool _loadingAdmins = true;

  // Developer alert-trigger tool
  final _householdQueryCtrl = TextEditingController();
  List<HouseholdSummary> _households = [];
  bool _searchingHouseholds = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdmins());
  }

  Future<void> _loadAdmins() async {
    try {
      final admins = await context.read<AuthProvider>().service.getAdmins();
      if (mounted) setState(() { _admins = admins; _loadingAdmins = false; });
    } catch (_) {
      if (mounted) setState(() { _admins = []; _loadingAdmins = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().user;
    final dev = context.watch<DevSettingsProvider>();
    final server = context.watch<ServerConfigProvider>();
    final effective = dev.effectiveRole(user) ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.developerTools)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Role preview ──────────────────────────────────────────────────
          _Label(l10n.rolePreview),
          const SizedBox(height: 6),
          Text(l10n.rolePreviewHint,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          _RoleSelector(
            current: effective,
            onSelect: (role) =>
                dev.setPreviewRole(role == 'Admin' ? null : role),
          ),
          if (dev.isPreviewing(user)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningAmber.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.visibility_outlined, size: 16, color: AppColors.warningAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.previewing}: ${l10n.roleLabel(effective)}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.warningAmber),
                  ),
                ),
                GestureDetector(
                  onTap: () => dev.setPreviewRole(null),
                  child: Text(l10n.exitPreview,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningAmber)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 28),

          // ── Server address ────────────────────────────────────────────────
          _Label(l10n.serverAddress),
          const SizedBox(height: 6),
          Text(l10n.serverAddressHint,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _editServer(context, server),
            child: _Tile(
              icon: Icons.dns_outlined,
              title: l10n.serverUrlField,
              subtitle: server.displayUrl,
              trailing: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
            ),
          ),
          const SizedBox(height: 28),

          // ── Admins ────────────────────────────────────────────────────────
          _Label(l10n.manageAdmins),
          const SizedBox(height: 6),
          Text(l10n.manageAdminsHint,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          if (_loadingAdmins)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ))
          else ...[
            ...(_admins ?? []).map((a) => _AdminTile(
                  admin: a,
                  isSelf: a.email.toLowerCase() == (user?.email.toLowerCase() ?? ''),
                  onRemove: () => _removeAdmin(a),
                )),
            const SizedBox(height: 10),
            VsButton(
              label: l10n.addAdmin,
              variant: VsButtonVariant.secondary,
              width: double.infinity,
              icon: Icons.person_add_alt,
              onPressed: _addAdmin,
            ),
          ],
          const SizedBox(height: 28),

          // ── Trigger alert (testing) ───────────────────────────────────────
          _Label('Disparar alerta (pruebas)'),
          const SizedBox(height: 6),
          Text(
              'Busca un hogar por nombre o correo y dispara una alerta real: se guarda '
              'en el historial, aparece en la cámara y envía el WhatsApp, como si hubiera ocurrido.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: VsTextField(
                controller: _householdQueryCtrl,
                label: 'Hogar (nombre o correo)',
                hint: 'Ej: Diego',
              ),
            ),
            const SizedBox(width: 10),
            VsButton(
              label: 'Buscar',
              variant: VsButtonVariant.secondary,
              icon: Icons.search,
              onPressed: _searchHouseholds,
            ),
          ]),
          const SizedBox(height: 10),
          if (_searchingHouseholds)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent)))
          else
            ..._households.map((h) => _HouseholdTile(
                  household: h,
                  onTrigger: () => _pickAndTrigger(h),
                )),
          const SizedBox(height: 28),

          // ── Diagnostics ───────────────────────────────────────────────────
          _Label(l10n.diagnostics),
          const SizedBox(height: 12),
          _Tile(icon: Icons.dns_outlined, title: 'Backend', subtitle: server.serverUrl),
          const SizedBox(height: 10),
          _Tile(icon: Icons.badge_outlined, title: l10n.role, subtitle: user?.role ?? '—'),
          const SizedBox(height: 10),
          _Tile(icon: Icons.info_outline, title: 'Version', subtitle: 'v${AppConstants.appVersion}'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _searchHouseholds() async {
    setState(() => _searchingHouseholds = true);
    try {
      final r = await context
          .read<AuthProvider>()
          .service
          .searchHouseholds(_householdQueryCtrl.text.trim());
      if (mounted) setState(() { _households = r; _searchingHouseholds = false; });
    } catch (_) {
      if (mounted) setState(() { _households = []; _searchingHouseholds = false; });
      _toast('Error al buscar hogares');
    }
  }

  Future<void> _pickAndTrigger(HouseholdSummary h) async {
    const options = <String, String>{
      'UnknownFace': 'Persona desconocida',
      'WeaponDetected': 'Arma detectada',
      'Tailgating': 'Merodeador detectado',
      'Climbing': 'Escalamiento',
      'PhysicalAggression': 'Agresión física',
    };
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Disparar alerta para ${h.name}',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ),
          ...options.entries.map((e) => ListTile(
                leading: const Icon(Icons.notifications_active_outlined,
                    color: AppColors.accent),
                title: Text(e.value,
                    style: GoogleFonts.inter(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, e.key),
              )),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (type == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().service.simulateEvent(h.householdId, type);
      messenger.showSnackBar(SnackBar(
          content: Text('Alerta "${options[type]}" enviada a ${h.name}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo disparar la alerta')));
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _addAdmin() async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final email = await showModalBottomSheet<String>(
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.addAdmin,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(l10n.adminAddHint,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 18),
            VsTextField(
              controller: ctrl,
              label: l10n.adminEmailField,
              hint: 'dev@correo.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? l10n.invalidEmail : null,
            ),
            const SizedBox(height: 20),
            VsButton(
              label: l10n.add,
              width: double.infinity,
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
              },
            ),
          ]),
        ),
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await context.read<AuthProvider>().service.addAdmin(email);
      await _loadAdmins();
      if (mounted) _snack(l10n.adminAdded, true);
    } catch (e) {
      if (mounted) _snack(e.toString(), false);
    }
  }

  Future<void> _removeAdmin(AdminUser a) async {
    final l10n = context.l10n;
    try {
      await context.read<AuthProvider>().service.removeAdmin(a.id);
      await _loadAdmins();
      if (mounted) _snack(l10n.adminRemoved, true);
    } catch (e) {
      if (mounted) _snack(e.toString(), false);
    }
  }

  void _editServer(BuildContext context, ServerConfigProvider server) {
    final l10n = context.l10n;
    final ctrl = TextEditingController(text: server.serverUrl);
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
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.serverAddress,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          VsTextField(controller: ctrl, label: l10n.serverUrlField, keyboardType: TextInputType.url),
          const SizedBox(height: 20),
          VsButton(
            label: l10n.saveAndReconnect,
            width: double.infinity,
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await context.read<ServerConfigProvider>().updateServerUrl(url);
              if (ok && context.mounted) {
                context.read<AuthProvider>().logout();
                _snack(l10n.serverUpdated, true);
              }
            },
          ),
        ]),
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
}

class _RoleSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _RoleSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const roles = ['Admin', 'Primary', 'Secondary'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: roles.map((r) {
          final selected = r == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  l10n.roleLabel(r),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.black : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final AdminUser admin;
  final bool isSelf;
  final VoidCallback onRemove;
  const _AdminTile({required this.admin, required this.isSelf, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.code, color: AppColors.warningAmber, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(admin.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              if (isSelf) ...[
                const SizedBox(width: 6),
                Text('· ${context.l10n.you}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.accent)),
              ],
            ]),
            Text(admin.email,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        if (!isSelf)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.alertRed, size: 20),
            onPressed: onRemove,
          ),
      ]),
    );
  }
}

class _HouseholdTile extends StatelessWidget {
  final HouseholdSummary household;
  final VoidCallback onTrigger;
  const _HouseholdTile({required this.household, required this.onTrigger});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.home_outlined, color: AppColors.accent, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(household.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(household.email,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        TextButton.icon(
          onPressed: onTrigger,
          icon: const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.accent),
          label: Text('Disparar',
              style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 1),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _Tile({required this.icon, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            Text(subtitle,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.accent)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
