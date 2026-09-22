import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';

/// Regla de contraseña segura de la aplicación.
///
/// Es el espejo exacto de `PasswordPolicy` del backend: si aquí se aceptara algo
/// que allá se rechaza, el usuario vería el formulario en verde y el servidor le
/// devolvería un error que no sabría interpretar.
class PasswordRules {
  static const int minLength = 8;

  static bool hasLength(String p) => p.length >= minLength;
  static bool hasUpper(String p) => p.contains(RegExp(r'[A-ZÁÉÍÓÚÑÜ]'));
  static bool hasLower(String p) => p.contains(RegExp(r'[a-záéíóúñü]'));
  static bool hasDigit(String p) => p.contains(RegExp(r'[0-9]'));
  static bool hasSymbol(String p) => p.contains(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑÜáéíóúñü]'));

  static List<bool> checks(String p) =>
      [hasLength(p), hasUpper(p), hasLower(p), hasDigit(p), hasSymbol(p)];

  static bool isValid(String p) => !checks(p).contains(false);

  /// Cuántos requisitos cumple, de 0 a 5.
  static int met(String p) => checks(p).where((c) => c).length;

  /// Mensaje para el `validator` del formulario (null = válida).
  static String? validate(String? p, AppStrings l10n) =>
      isValid(p ?? '') ? null : l10n.passwordWeak;
}

/// Checklist que se marca en tiempo real mientras se escribe la contraseña,
/// con una barra que indica su fuerza. Se coloca justo debajo del campo.
class PasswordStrength extends StatelessWidget {
  /// Texto actual del campo. Usar con un [ValueListenableBuilder] o un
  /// `setState` en `onChanged` para que se actualice a cada tecla.
  final String password;

  const PasswordStrength({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final checks = PasswordRules.checks(password);
    final met = PasswordRules.met(password);
    final etiquetas = [
      l10n.pwRuleLength(PasswordRules.minLength),
      l10n.pwRuleUpper,
      l10n.pwRuleLower,
      l10n.pwRuleDigit,
      l10n.pwRuleSymbol,
    ];

    // Vacío: no se regaña al usuario antes de que escriba nada.
    if (password.isEmpty) return const SizedBox.shrink();

    final (color, texto) = switch (met) {
      5 => (AppColors.safeGreen, l10n.pwStrong),
      4 => (AppColors.warningAmber, l10n.pwMedium),
      _ => (AppColors.alertRed, l10n.pwWeak),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: met / 5,
                    minHeight: 5,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(texto,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < etiquetas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(
                    checks[i] ? Icons.check_circle : Icons.circle_outlined,
                    size: 14,
                    color: checks[i] ? AppColors.safeGreen : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    etiquetas[i],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: checks[i] ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
