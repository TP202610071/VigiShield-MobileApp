import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/user_service.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';
import '../../widgets/sheet_header.dart';

/// Gestión de los residentes secundarios del hogar. Sólo la ve el residente
/// principal: es quien decide a quién deja ver su vivienda.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UserService _service = UserService(context.read<ApiClient>());

  List<SecondaryUser> _users = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final u = await _service.getSecondaryUsers();
      if (mounted) setState(() { _users = u; _cargando = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _cargando = false; });
    }
  }

  void _aviso(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: ok ? AppColors.safeGreen : AppColors.alertRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _invitar() async {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(titulo: l10n.inviteUserTitle),
              const SizedBox(height: 4),
              Text(l10n.inviteUserHint,
                  style: GoogleFonts.inter(
                      fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              VsTextField(
                label: l10n.emailField,
                controller: ctrl,
                hint: 'persona@correo.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? l10n.invalidEmail : null,
              ),
              const SizedBox(height: 20),
              VsButton(
                label: l10n.inviteUser,
                width: double.infinity,
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, ctrl.text.trim());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (email == null || email.isEmpty) return;
    try {
      await _service.invite(email);
      if (!mounted) return;
      _aviso(context.l10n.inviteSent, true);
      await _cargar();
    } on ApiException catch (e) {
      _aviso(e.message, false);
    }
  }

  Future<void> _revocar(SecondaryUser u) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.revokeAccess,
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(l10n.revokeAccessConfirm(u.name),
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.revokeAccess,
                style: GoogleFonts.inter(
                    color: AppColors.alertRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.revoke(u.id);
      if (!mounted) return;
      _aviso(context.l10n.accessRevoked, true);
      await _cargar();
    } on ApiException catch (e) {
      _aviso(e.message, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(l10n.householdUsers,
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: _invitar,
        icon: const Icon(Icons.person_add_alt, color: Colors.black),
        label: Text(l10n.inviteUser,
            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: _build(l10n),
      ),
    );
  }

  Widget _build(AppStrings l10n) {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
    }
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.wifi_off_outlined, color: AppColors.textSecondary, size: 48),
        const SizedBox(height: 16),
        Center(
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
              onPressed: _cargar,
              child: Text(l10n.retry, style: GoogleFonts.inter(color: AppColors.accent))),
        ),
      ]);
    }
    if (_users.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 90),
        const Icon(Icons.group_outlined, color: AppColors.textSecondary, size: 56),
        const SizedBox(height: 16),
        Center(
          child: Text(l10n.noSecondaryUsers,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(l10n.noSecondaryUsersHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        ),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 2, right: 2),
          child: Text(l10n.householdUsersHint,
              style: GoogleFonts.inter(
                  fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
        ),
        for (final u in _users) _tarjeta(u, l10n),
      ],
    );
  }

  Widget _tarjeta(SecondaryUser u, AppStrings l10n) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(u.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                l10n.memberSinceShort(DateFormat(l10n.dateFormatShort, l10n.localeCode)
                    .format(u.createdAt.toLocal())),
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
              ),
            ]),
          ),
          IconButton(
            onPressed: () => _revocar(u),
            icon: const Icon(Icons.person_remove_outlined,
                color: AppColors.alertRed, size: 20),
            tooltip: l10n.revokeAccess,
          ),
        ]),
      );
}
