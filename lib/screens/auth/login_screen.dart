import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await context.read<AuthProvider>().login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) {
      final error =
          context.read<AuthProvider>().errorMessage ?? context.l10n.loginError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showForgotPassword(BuildContext context) {
    final l10n = context.l10n;
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;
    bool sent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 28,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.recoverPassword,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (!sent) ...[
              Text(
                l10n.recoverHint,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              VsTextField(
                controller: emailCtrl,
                label: l10n.emailField,
                hint: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              VsButton(
                label: l10n.sendLink,
                isLoading: sending,
                onPressed: sending ? null : () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) return;
                  setS(() => sending = true);
                  try {
                    final authService = context.read<AuthProvider>().service;
                    await authService.recoverPassword(email);
                    setS(() { sending = false; sent = true; });
                  } catch (_) {
                    setS(() => sending = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(l10n.error,
                            style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: AppColors.alertRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  }
                },
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.safeGreen.withAlpha(77)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.safeGreen, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.linkSent(emailCtrl.text.trim()),
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13, height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              VsButton(
                label: l10n.close,
                variant: VsButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // ── Logo row ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withAlpha(77)),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('VigiShield',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),

                const SizedBox(height: 48),
                Text(
                  l10n.welcome,
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.loginSubtitle,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 32),
                VsTextField(
                  label: l10n.emailField,
                  hint: 'tu@correo.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.requiredField;
                    if (!v.contains('@')) return l10n.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                VsTextField(
                  label: l10n.passwordField,
                  hint: '••••••••',
                  controller: _passwordCtrl,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _login,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.requiredField;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _showForgotPassword(context),
                    child: Text(
                      l10n.forgotPassword,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                VsButton(
                  label: l10n.login,
                  onPressed: _isLoading ? null : _login,
                  isLoading: _isLoading,
                  width: double.infinity,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.noAccount,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text(
                        l10n.createAccount,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
