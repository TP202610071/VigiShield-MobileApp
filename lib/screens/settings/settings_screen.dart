import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/server_config_provider.dart';
import '../../providers/system_provider.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Ajustes',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          user?.name.substring(0, 1).toUpperCase() ?? '?',
                          style: GoogleFonts.inter(
                            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (user?.isPrimary ?? false)
                                  ? AppColors.accent.withOpacity(0.1)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (user?.isPrimary ?? false)
                                    ? AppColors.accent.withOpacity(0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              (user?.isPrimary ?? false)
                                  ? 'residente principal'
                                  : 'residente secundario',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: (user?.isPrimary ?? false)
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _SectionLabel('CUENTA'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Cambiar contraseña',
                onTap: () => _showChangePasswordDialog(context),
              ),
              const SizedBox(height: 24),

              if (user?.isPrimary ?? false) ...[
                _SectionLabel('SISTEMA'),
                const SizedBox(height: 8),
                _AlertConfigTile(),
                const SizedBox(height: 16),
                _SettingsTile(
                  icon: Icons.videocam_outlined,
                  label: 'Mis cámaras',
                  onTap: () => context.push('/settings/cameras'),
                ),
                const SizedBox(height: 16),
                _SettingsTile(
                  icon: Icons.face_outlined,
                  label: 'Caras autorizadas',
                  onTap: () => context.push('/settings/faces'),
                ),
                const SizedBox(height: 24),
              ],

              _SectionLabel('SERVIDOR'),
              const SizedBox(height: 8),
              _ServerUrlTile(),
              const SizedBox(height: 24),

              _SectionLabel('CONEXIÓN'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.dns_outlined, color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Información',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.textPrimary)),
                          Text('VigiShield v1.0.0 MVP',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              VsButton(
                label: 'Cerrar sesión',
                variant: VsButtonVariant.danger,
                width: double.infinity,
                icon: Icons.logout,
                onPressed: () => _showLogoutDialog(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cerrar sesión',
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('¿Deseas cerrar tu sesión?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: Text('Cerrar sesión',
                style: GoogleFonts.inter(color: AppColors.alertRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 28,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cambiar contraseña',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              VsTextField(
                label: 'CONTRASEÑA ACTUAL',
                controller: currentCtrl,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (v) => (v?.isEmpty ?? true) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              VsTextField(
                label: 'NUEVA CONTRASEÑA',
                controller: newCtrl,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) => (v?.length ?? 0) < 8 ? 'Mínimo 8 caracteres' : null,
              ),
              const SizedBox(height: 24),
              VsButton(
                label: 'Guardar cambios',
                width: double.infinity,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final ok = await context.read<AuthProvider>()
                      .changePassword(currentCtrl.text, newCtrl.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        ok ? 'Contraseña actualizada' : (context.read<AuthProvider>().errorMessage ?? 'Error'),
                      ),
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 1),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AlertConfigTile extends StatefulWidget {
  @override
  State<_AlertConfigTile> createState() => _AlertConfigTileState();
}

class _AlertConfigTileState extends State<_AlertConfigTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemProvider>().fetchAlertConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SystemProvider>().alertConfig;

    return GestureDetector(
      onTap: config != null ? () => _showAlertConfig(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Configurar alertas',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            ),
            if (config == null)
              const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            else
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showAlertConfig(BuildContext context) {
    final config = context.read<SystemProvider>().alertConfig!;
    var draft = config;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 28,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configurar alertas',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _SwitchRow('Persona desconocida', draft.unknownPersonEnabled,
                  (v) => setS(() => draft = draft.copyWith(unknownPersonEnabled: v))),
              _SwitchRow('Acceso forzado', draft.forcedAccessEnabled,
                  (v) => setS(() => draft = draft.copyWith(forcedAccessEnabled: v))),
              _SwitchRow('Merodeador', draft.tailgatingEnabled,
                  (v) => setS(() => draft = draft.copyWith(tailgatingEnabled: v))),
              _SwitchRow('Escalamiento', draft.climbingEnabled,
                  (v) => setS(() => draft = draft.copyWith(climbingEnabled: v))),
              _SwitchRow('Agresión física', draft.aggressionEnabled,
                  (v) => setS(() => draft = draft.copyWith(aggressionEnabled: v))),
              const SizedBox(height: 20),
              VsButton(
                label: 'Guardar',
                width: double.infinity,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<SystemProvider>().updateAlertConfig(draft);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Server URL tile ───────────────────────────────────────────────────────────

class _ServerUrlTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerConfigProvider>();

    return GestureDetector(
      onTap: () => _showServerDialog(context, server),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.dns_outlined,
              color: AppColors.accent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dirección del servidor',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textPrimary)),
                  Text(
                    server.displayUrl,
                    style: GoogleFonts.robotoMono(
                        fontSize: 11, color: AppColors.accent),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (server.isEmulatorDefault)
                    Text(
                      '⚠️ Esto solo funciona en el emulador. '
                      'Si usas un móvil real, cámbialo a la IP de tu PC.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.warningAmber),
                    ),
                ]),
          ),
          const Icon(Icons.edit_outlined,
              color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  void _showServerDialog(
      BuildContext context, ServerConfigProvider server) {
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
          Text('Dirección del servidor',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Escribe la IP de tu PC seguida del puerto 5020.\n'
            'Ejemplo: http://192.168.1.76:5020\n\n'
            'Solo en el emulador Android usa: http://10.0.2.2:5020',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          VsTextField(
            controller: ctrl,
            label: 'URL del servidor',
            hint: 'http://192.168.1.76:5020',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          VsButton(
            label: 'Guardar y reconectar',
            onPressed: () async {
              final newUrl = ctrl.text.trim();
              if (newUrl.isEmpty) return;
              Navigator.pop(ctx);

              final ok = await context
                  .read<ServerConfigProvider>()
                  .updateServerUrl(newUrl);

              if (context.mounted) {
                if (ok) {
                  // Log out so user re-authenticates against the new server
                  context.read<AuthProvider>().logout();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Servidor actualizado. Inicia sesión de nuevo.',
                        style: GoogleFonts.inter(color: Colors.white)),
                    backgroundColor: AppColors.safeGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }
              }
            },
          ),
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.accent.withOpacity(0.3)
                    : AppColors.border),
          ),
        ],
      ),
    );
  }
}
