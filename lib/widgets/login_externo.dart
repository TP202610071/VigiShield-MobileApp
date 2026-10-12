import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/i18n/app_localizations.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../data/services/login_externo_service.dart';
import '../providers/auth_provider.dart';
import 'vs_cargando.dart';

/// Muestra «Continuar con Google» desactivado con «Próximamente». Ponerlo en
/// false para ocultarlo (por ejemplo, si la revisión de Apple lo objeta).
const bool kMostrarGoogleProximamente = true;

/// «Continuar con Apple» y «Continuar con Google» (próximamente), debajo del
/// botón de iniciar sesión o de crear cuenta.
///
/// Apple se ofrece en iPhone siempre, y en Android solo si el backend tiene el
/// Services ID configurado (allí va por la web de Apple).
class BotonesLoginExterno extends StatefulWidget {
  const BotonesLoginExterno({super.key, this.servicio});

  /// Para pruebas.
  final LoginExternoService? servicio;

  @override
  State<BotonesLoginExterno> createState() => _BotonesLoginExternoState();
}

class _BotonesLoginExternoState extends State<BotonesLoginExterno> {
  late final LoginExternoService? _servicio = widget.servicio ??
      switch (context.read<ApiClient?>()) { final ApiClient api => LoginExternoService(api), null => null };
  bool _apple = false;
  AppleAndroid? _android;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final servicio = _servicio;
    if (servicio == null) return;
    var apple = false;
    AppleAndroid? android;
    if (LoginExternoService.esIos) {
      try {
        apple = await SignInWithApple.isAvailable();
      } catch (_) {}
    } else if (LoginExternoService.esAndroid) {
      android = await servicio.configAndroid();
      apple = android != null;
    }
    if (mounted) {
      setState(() {
        _apple = apple;
        _android = android;
      });
    }
  }

  Future<void> _conApple() async {
    final error = context.l10n.loginExternoError;
    setState(() => _cargando = true);
    try {
      final resultado = await _servicio!.conApple(android: _android);
      if (!mounted) return;
      await context.read<AuthProvider>().iniciarSesionExterna(resultado);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) _error(error);
    } on ApiException catch (e) {
      _error(e.message);
    } catch (_) {
      _error(error);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _error(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(texto, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: AppColors.alertRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_apple && !kMostrarGoogleProximamente) return const SizedBox.shrink();
    final s = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(s.loginExternoO, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ]),
      const SizedBox(height: 16),
      if (_apple) ...[
        SizedBox(
          height: 52,
          width: double.infinity,
          child: _cargando
              ? Center(child: VsCargando(size: 28, color: AppColors.accent))
              : SignInWithAppleButton(
                  key: const Key('boton-apple'),
                  text: s.loginConApple,
                  height: 52,
                  style: AppColors.esClaro ? SignInWithAppleButtonStyle.black : SignInWithAppleButtonStyle.white,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  onPressed: _conApple,
                ),
        ),
        const SizedBox(height: 12),
      ],
      if (kMostrarGoogleProximamente) _GoogleProximamente(texto: s.loginConGoogle, etiqueta: s.proximamente),
    ]);
  }
}

/// Botón de Google desactivado, con «Próximamente» encima.
class _GoogleProximamente extends StatelessWidget {
  final String texto;
  final String etiqueta;
  const _GoogleProximamente({required this.texto, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$texto. $etiqueta',
      child: ExcludeSemantics(
        child: Stack(clipBehavior: Clip.none, children: [
          Opacity(
            opacity: 0.5,
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('G',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                Text(texto,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ]),
            ),
          ),
          Positioned(
            right: 12,
            top: -9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(etiqueta,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onAccent, letterSpacing: 0.2)),
            ),
          ),
        ]),
      ),
    );
  }
}

extension LoginExternoStrings on AppStrings {
  String get loginExternoO => en ? 'or' : 'o';
  String get loginConApple => en ? 'Continue with Apple' : 'Continuar con Apple';
  String get loginConGoogle => en ? 'Continue with Google' : 'Continuar con Google';
  String get proximamente => en ? 'Coming soon' : 'Próximamente';
  String get loginExternoError =>
      en ? 'Could not sign in with Apple. Try again.' : 'No se pudo iniciar sesión con Apple. Inténtalo de nuevo.';
  String get eliminarConApple => en ? 'Confirm with Apple' : 'Confirmar con Apple';
  String get eliminarConAppleTexto => en
      ? 'You signed in with Apple. To confirm it is you, sign in with Apple again.'
      : 'Entraste con Apple. Para confirmar que eres tú, vuelve a entrar con Apple.';
}

/// Dentro del diálogo «Eliminar cuenta»: si la cuenta está vinculada a Apple,
/// permite confirmar con Apple en vez de con la contraseña (las cuentas
/// creadas con Apple no tienen una).
class ConfirmarEliminarConApple extends StatefulWidget {
  const ConfirmarEliminarConApple({super.key, this.servicio});

  /// Para pruebas.
  final LoginExternoService? servicio;

  @override
  State<ConfirmarEliminarConApple> createState() => _ConfirmarEliminarConAppleState();
}

class _ConfirmarEliminarConAppleState extends State<ConfirmarEliminarConApple> {
  late final LoginExternoService? _servicio = widget.servicio ??
      switch (context.read<ApiClient?>()) { final ApiClient api => LoginExternoService(api), null => null };
  bool _vinculada = false;
  bool _enviando = false;
  AppleAndroid? _android;
  String? _error;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final servicio = _servicio;
    if (servicio == null) return;
    final estado = await servicio.estado();
    final android = estado.apple && LoginExternoService.esAndroid ? await servicio.configAndroid() : null;
    // En Android sin Services ID no se puede volver a entrar con Apple.
    final disponible = estado.apple && (LoginExternoService.esIos || android != null);
    if (!mounted) return;
    setState(() {
      _vinculada = disponible;
      _android = android;
    });
  }

  Future<void> _confirmar() async {
    final s = context.l10n;
    final auth = context.read<AuthProvider>();
    final navegador = Navigator.of(context);
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final ok = await auth.eliminarCuentaCon(() => _servicio!.eliminarConApple(android: _android));
      if (ok) {
        navegador.pop(true);
        return;
      }
      _error = auth.errorMessage ?? s.deleteAccountError;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) _error = s.loginExternoError;
    } catch (_) {
      _error = s.loginExternoError;
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_vinculada) return const SizedBox.shrink();
    final s = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(s.eliminarConAppleTexto,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: _enviando
              ? Center(child: VsCargando(size: 24, color: AppColors.alertRed))
              : SignInWithAppleButton(
                  key: const Key('eliminar-con-apple'),
                  text: s.eliminarConApple,
                  height: 46,
                  style: AppColors.esClaro ? SignInWithAppleButtonStyle.black : SignInWithAppleButtonStyle.white,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onPressed: _confirmar,
                ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: GoogleFonts.inter(color: AppColors.alertRed, fontSize: 12)),
        ],
      ]),
    );
  }
}
