import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tema_provider.dart';

/// Fila de Ajustes para elegir el modo: sistema, claro u oscuro. Mismo estilo
/// que la del idioma.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key});

  static IconData iconoDe(ModoTema m) => switch (m) {
        ModoTema.sistema => Icons.brightness_auto_outlined,
        ModoTema.claro => Icons.light_mode_outlined,
        ModoTema.oscuro => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final tema = context.watch<TemaProvider?>();
    if (tema == null) return const SizedBox.shrink();
    final modo = tema.modo;
    return GestureDetector(
      onTap: () => _mostrar(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(iconoDe(modo), color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.temaTitulo, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
          ),
          Text(s.temaNombre(modo), style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  void _mostrar(BuildContext context) {
    final s = context.l10n;
    final tema = context.read<TemaProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          for (final m in ModoTema.values)
            ListTile(
              leading: Icon(iconoDe(m), color: m == tema.modo ? AppColors.accent : AppColors.textSecondary),
              title: Text(s.temaNombre(m), style: GoogleFonts.inter(color: AppColors.textPrimary)),
              subtitle: m == ModoTema.sistema
                  ? Text(s.temaSistemaDetalle, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12))
                  : null,
              trailing: m == tema.modo ? Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () {
                Navigator.pop(ctx);
                tema.cambiar(m);
              },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

extension TemaStrings on AppStrings {
  String get temaTitulo => en ? 'Appearance' : 'Apariencia';
  String get temaSistemaDetalle => en ? 'Follows your phone setting' : 'Sigue el ajuste del teléfono';
  String temaNombre(ModoTema m) => switch (m) {
        ModoTema.sistema => en ? 'System' : 'Sistema',
        ModoTema.claro => en ? 'Light' : 'Claro',
        ModoTema.oscuro => en ? 'Dark' : 'Oscuro',
      };
}
