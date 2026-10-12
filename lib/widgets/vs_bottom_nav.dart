import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';

class VsBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Oscura aunque la app esté en modo claro: bajo la pestaña Cámara, que
  /// siempre es oscura, una barra blanca se ve cortada.
  final bool oscura;

  const VsBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.oscura = false,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _NavItemData(icon: Icons.videocam_outlined, activeIcon: Icons.videocam_rounded),
    _NavItemData(icon: Icons.history_outlined, activeIcon: Icons.history),
    _NavItemData(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
  ];

  static String _label(AppStrings l10n, int i) => switch (i) {
        0 => l10n.navHome,
        1 => l10n.navCamera,
        2 => l10n.navHistory,
        _ => l10n.navSettings,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fondo = oscura ? AppColorsOscuros.surface : AppColors.surface;
    final borde = oscura ? AppColorsOscuros.border : AppColors.border;
    final acento = oscura ? AppColorsOscuros.accent : AppColors.accent;
    final apagado = oscura ? AppColorsOscuros.textSecondary : AppColors.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: fondo,
        border: Border(top: BorderSide(color: borde, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: isActive ? 32 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: acento,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedScale(
                          scale: isActive ? 1.12 : 1,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isActive ? item.activeIcon : item.icon,
                              key: ValueKey(isActive),
                              color: isActive ? acento : apagado,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _label(l10n, i),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? acento : apagado,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;

  const _NavItemData({required this.icon, required this.activeIcon});
}
