import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_strength.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

/// Restablecimiento de contraseña dentro de la app, al que se llega desde el
/// enlace del correo. Es PÚBLICA: se usa justamente cuando no se puede entrar.
/// La misma operación existe como página web para quien no tenga la app.
class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String _password = '';
  bool _enviando = false;
  bool _listo = false;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _enviando = true; _error = null; });
    final ok = await context.read<AuthProvider>().resetPassword(widget.token, _p1.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _listo = ok;
      _error = ok ? null : (context.read<AuthProvider>().errorMessage ?? context.l10n.resetLinkInvalid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
                  child: const Icon(Icons.shield_outlined, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Text('VigiShield',
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 48),
              Text(l10n.resetTitle,
                  style: GoogleFonts.inter(
                      fontSize: 28, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 6),

              if (_listo) ...[
                const SizedBox(height: 16),
                _Aviso(
                  icon: Icons.check_circle_outline,
                  color: AppColors.safeGreen,
                  text: l10n.resetDone,
                ),
                const SizedBox(height: 24),
                VsButton(
                  label: l10n.login,
                  width: double.infinity,
                  onPressed: () => context.go('/login'),
                ),
              ] else ...[
                Text(l10n.resetSubtitle,
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  _Aviso(icon: Icons.error_outline, color: AppColors.alertRed, text: _error!),
                  const SizedBox(height: 16),
                ],
                Form(
                  key: _formKey,
                  child: Column(children: [
                    VsTextField(
                      label: l10n.newPassword,
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
                      onEditingComplete: _guardar,
                      validator: (v) =>
                          v != _p1.text ? l10n.passwordsDoNotMatch : null,
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                VsButton(
                  label: l10n.savePassword,
                  width: double.infinity,
                  isLoading: _enviando,
                  onPressed: _enviando ? null : _guardar,
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(l10n.backToLogin,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
                  ),
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
