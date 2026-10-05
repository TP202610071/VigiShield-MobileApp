import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';

/// «He leído y acepto los Términos y condiciones y la Política de privacidad»,
/// con los dos enlaces a vigishield.app.
class TextoTerminos extends StatefulWidget {
  const TextoTerminos({super.key, this.color = AppColors.textSecondary});
  final Color color;

  @override
  State<TextoTerminos> createState() => _TextoTerminosState();
}

class _TextoTerminosState extends State<TextoTerminos> {
  late final TapGestureRecognizer _terminos;
  late final TapGestureRecognizer _privacidad;

  @override
  void initState() {
    super.initState();
    _terminos = TapGestureRecognizer()..onTap = () => _abrir(kUrlTerminos);
    _privacidad = TapGestureRecognizer()..onTap = () => _abrir(kUrlPrivacidad);
  }

  @override
  void dispose() {
    _terminos.dispose();
    _privacidad.dispose();
    super.dispose();
  }

  Future<void> _abrir(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = GoogleFonts.inter(fontSize: 13, color: widget.color, height: 1.4);
    final enlace = base.copyWith(
        color: AppColors.accent, decoration: TextDecoration.underline,
        decorationColor: AppColors.accent);
    return Text.rich(TextSpan(style: base, children: [
      TextSpan(text: l10n.termsAcceptPrefix),
      TextSpan(text: l10n.termsLink, style: enlace, recognizer: _terminos),
      TextSpan(text: l10n.termsAnd),
      TextSpan(text: l10n.privacyLink, style: enlace, recognizer: _privacidad),
      const TextSpan(text: '.'),
    ]));
  }
}
