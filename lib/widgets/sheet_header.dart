import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

/// Encabezado estándar de una hoja inferior: asa para arrastrar, título y
/// botón de cerrar.
///
/// Varias hojas (configurar alertas, invitar, agregar cámara) no ofrecían
/// ninguna forma visible de salir: solo tenían el botón de guardar, así que
/// quien no supiera que se puede arrastrar hacia abajo quedaba atrapado.
class SheetHeader extends StatelessWidget {
  final String titulo;

  /// Acción opcional a la derecha del título (p. ej. "Desactivar todas").
  final Widget? accion;

  /// Qué hacer al cerrar. Por defecto cierra la hoja.
  final VoidCallback? onCerrar;

  const SheetHeader({
    super.key,
    required this.titulo,
    this.accion,
    this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                titulo,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (accion != null) accion!,
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary, size: 22),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onCerrar ?? () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
