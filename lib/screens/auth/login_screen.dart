import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/server_config_provider.dart';
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
          context.read<AuthProvider>().errorMessage ?? 'Error al iniciar sesión';
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
            Text('Recuperar contraseña',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (!sent) ...[
              Text(
                'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              VsTextField(
                controller: emailCtrl,
                label: 'CORREO ELECTRÓNICO',
                hint: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              VsButton(
                label: 'Enviar enlace',
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
                        content: Text('Error al enviar. Verifica el correo.',
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
              // Success state
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
                      'Enlace enviado a ${emailCtrl.text.trim()}.\n'
                      'Revisa tu bandeja de entrada.',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13, height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              VsButton(
                label: 'Cerrar',
                variant: VsButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  void _showServerDialog() {
    final server = context.read<ServerConfigProvider>();
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
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Handle bar
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
          Text('Dirección del servidor',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Escribe la IP de tu PC y el puerto 5020.\n'
            '📱 Dispositivo real en tu WiFi → http://IP_DE_TU_PC:5020\n'
            '🖥️  Emulador Android → http://10.0.2.2:5020',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 16),
          // IP auto-hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withAlpha(51)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Para saber tu IP: abre cmd en tu PC y escribe ipconfig. '
                  'Busca "Dirección IPv4" en tu adaptador WiFi.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          VsTextField(
            controller: ctrl,
            label: 'URL del servidor',
            hint: 'http://192.168.1.76:5020',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          VsButton(
            label: 'Conectar',
            onPressed: () async {
              final newUrl = ctrl.text.trim();
              if (newUrl.isEmpty) return;
              Navigator.pop(ctx);
              await context.read<ServerConfigProvider>().updateServerUrl(newUrl);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'Conectando a ${context.read<ServerConfigProvider>().displayUrl}…',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerConfigProvider>();

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

                // ── Logo row + server button ──────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accent.withAlpha(77)),
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
                    const Spacer(),
                    // Server config button — always visible on login screen
                    GestureDetector(
                      onTap: _showServerDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: server.isEmulatorDefault
                              ? AppColors.warningAmber.withAlpha(26)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: server.isEmulatorDefault
                                ? AppColors.warningAmber.withAlpha(128)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            Icons.dns_outlined,
                            color: server.isEmulatorDefault
                                ? AppColors.warningAmber
                                : AppColors.accent,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            server.isEmulatorDefault
                                ? 'Emulador'
                                : server.displayUrl
                                    .replaceAll(':5020', '')
                                    .replaceAll('http://', ''),
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: server.isEmulatorDefault
                                  ? AppColors.warningAmber
                                  : AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),
                Text(
                  'Bienvenido',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicia sesión para acceder a tu sistema de seguridad',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary),
                ),

                // ── Warning banner when on emulator default ───────────────
                if (server.isEmulatorDefault) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showServerDialog,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warningAmber.withAlpha(102)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: AppColors.warningAmber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¿Usas un móvil real? Toca aquí para configurar '
                            'la dirección IP de tu servidor.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.warningAmber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.warningAmber, size: 16),
                      ]),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                VsTextField(
                  label: 'CORREO ELECTRÓNICO',
                  hint: 'tu@correo.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                VsTextField(
                  label: 'CONTRASEÑA',
                  hint: '••••••••',
                  controller: _passwordCtrl,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _login,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo requerido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _showForgotPassword(context),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
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
                  label: 'Iniciar sesión',
                  onPressed: _isLoading ? null : _login,
                  isLoading: _isLoading,
                  width: double.infinity,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text(
                        'Crear cuenta',
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
