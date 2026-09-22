import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/user_service.dart';
import '../../widgets/password_strength.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

/// Aceptación de una invitación desde el enlace del correo. Es PÚBLICA: quien
/// llega aquí todavía no tiene cuenta. La misma operación existe como página web
/// para quien no tenga la app instalada.
class AcceptInvitationScreen extends StatefulWidget {
  final String token;
  const AcceptInvitationScreen({super.key, required this.token});

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  late final UserService _service = UserService(context.read<ApiClient>());
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();

  InvitationInfo? _info;
  bool _cargando = true;
  bool _enviando = false;
  bool _listo = false;
  String _password = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _name.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final info = await _service.getInvitation(widget.token);
      if (mounted) setState(() { _info = info; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() { _cargando = false; _error = context.l10n.connectionError; });
    }
  }

  Future<void> _aceptar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _enviando = true; _error = null; });
    try {
      await _service.acceptInvitation(widget.token, _name.text.trim(), _p1.text);
      if (mounted) setState(() { _enviando = false; _listo = true; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _enviando = false; _error = e.message; });
    }
  }

  String _motivo(AppStrings l10n) => switch (_info?.reason) {
        'ya_usada' => l10n.inviteUsed,
        'caducada' => l10n.inviteExpired,
        _ => l10n.inviteInvalid,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = _info;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('VigiShield',
                          style: GoogleFonts.inter(
                              fontSize: 22, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ]),
                    const SizedBox(height: 48),
                    Text(l10n.inviteTitle,
                        style: GoogleFonts.inter(
                            fontSize: 26, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary, letterSpacing: -0.5)),
                    const SizedBox(height: 10),

                    if (_listo) ...[
                      _Aviso(
                        icon: Icons.check_circle_outline,
                        color: AppColors.safeGreen,
                        text: l10n.inviteDone,
                      ),
                      const SizedBox(height: 24),
                      VsButton(
                        label: l10n.login,
                        width: double.infinity,
                        onPressed: () => context.go('/login'),
                      ),
                    ] else if (info == null || !info.valid) ...[
                      _Aviso(
                        icon: Icons.error_outline,
                        color: AppColors.alertRed,
                        text: info == null ? (_error ?? l10n.inviteInvalid) : _motivo(l10n),
                      ),
                      const SizedBox(height: 24),
                      VsButton(
                        label: l10n.backToLogin,
                        variant: VsButtonVariant.secondary,
                        width: double.infinity,
                        onPressed: () => context.go('/login'),
                      ),
                    ] else ...[
                      _Aviso(
                        icon: Icons.home_outlined,
                        color: AppColors.accent,
                        text: l10n.invitedBy(info.invitedBy ?? l10n.roleLabel('Primary')) +
                            (info.householdAddress != null
                                ? ' (${info.householdAddress})'
                                : ''),
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.inviteSubtitle,
                          style: GoogleFonts.inter(
                              fontSize: 13, height: 1.5,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        _Aviso(icon: Icons.error_outline,
                            color: AppColors.alertRed, text: _error!),
                        const SizedBox(height: 16),
                      ],
                      Form(
                        key: _formKey,
                        child: Column(children: [
                          _CampoFijo(label: l10n.yourEmail, value: info.email ?? ''),
                          const SizedBox(height: 18),
                          VsTextField(
                            label: l10n.yourName,
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.trim().length < 2) ? l10n.nameMin : null,
                          ),
                          const SizedBox(height: 18),
                          VsTextField(
                            label: l10n.createYourPassword,
                            controller: _p1,
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            onChanged: (v) => setState(() => _password = v),
                            validator: (v) => PasswordRules.validate(v, l10n),
                          ),
                          PasswordStrength(password: _password),
                          const SizedBox(height: 18),
                          VsTextField(
                            label: l10n.repeatPassword,
                            controller: _p2,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            onEditingComplete: _aceptar,
                            validator: (v) =>
                                v != _p1.text ? l10n.passwordsDoNotMatch : null,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 28),
                      VsButton(
                        label: l10n.inviteAccept,
                        width: double.infinity,
                        isLoading: _enviando,
                        onPressed: _enviando ? null : _aceptar,
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Campo de solo lectura: el correo lo fija la invitación, no se puede cambiar.
class _CampoFijo extends StatelessWidget {
  final String label, value;
  const _CampoFijo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(value,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
          ),
        ],
      );
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Aviso({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
          ),
        ]),
      );
}
