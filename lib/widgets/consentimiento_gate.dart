import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'texto_terminos.dart';

/// Pide aceptar los Términos y la Política de privacidad a quien tenga la
/// sesión iniciada sin haberlos aceptado: cuentas creadas antes de que
/// existieran, residentes invitados o un cambio de versión. Está encima del
/// router, así que no se puede usar la app sin aceptar o cerrar sesión.
class ConsentimientoGate extends StatefulWidget {
  const ConsentimientoGate({super.key, required this.child});
  final Widget child;

  @override
  State<ConsentimientoGate> createState() => _ConsentimientoGateState();
}

class _ConsentimientoGateState extends State<ConsentimientoGate> {
  bool _guardando = false;

  Future<void> _aceptar() async {
    setState(() => _guardando = true);
    final ok = await context.read<AuthProvider>().aceptarTerminos();
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(context.l10n.consentError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final pedir = auth.isAuthenticated && user != null && !user.aceptoTerminosVigentes;
    if (!pedir) return widget.child;
    final l10n = context.l10n;
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      Positioned.fill(
        child: Material(
          color: AppColors.background,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.privacy_tip_outlined, color: AppColors.accent, size: 44),
                      const SizedBox(height: 16),
                      Text(l10n.consentTitle,
                          style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(l10n.consentBody,
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
                      const SizedBox(height: 16),
                      const TextoTerminos(color: AppColors.textPrimary),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _guardando ? null : _aceptar,
                          child: _guardando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(l10n.consentAccept),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _guardando ? null : () => auth.logout(),
                          child: Text(l10n.consentLogout,
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
