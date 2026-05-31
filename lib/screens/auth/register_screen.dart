import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/vs_button.dart';
import '../../widgets/vs_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await context.read<AuthProvider>().register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
          householdAddress: _addressCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) {
      final error = context.read<AuthProvider>().errorMessage ?? 'Error al registrarse';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Crear cuenta',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configura tu sistema VigiShield',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                VsTextField(
                  label: 'NOMBRE COMPLETO',
                  hint: 'Tu nombre',
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v?.length ?? 0) < 2 ? 'Mínimo 2 caracteres' : null,
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
                VsTextField(
                  label: 'CONTRASEÑA',
                  hint: 'Mínimo 8 caracteres',
                  controller: _passwordCtrl,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v?.length ?? 0) < 8 ? 'Mínimo 8 caracteres' : null,
                ),
                const SizedBox(height: 18),
                VsTextField(
                  label: 'DIRECCIÓN DEL HOGAR',
                  hint: 'Av. Ejemplo 123, Lima',
                  controller: _addressCtrl,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _register,
                  validator: (v) => (v?.length ?? 0) < 5 ? 'Dirección muy corta' : null,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Serás el residente principal con acceso completo al sistema.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                VsButton(
                  label: 'Crear cuenta',
                  onPressed: _isLoading ? null : _register,
                  isLoading: _isLoading,
                  width: double.infinity,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Ya tienes cuenta? ',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text('Iniciar sesión',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600)),
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
