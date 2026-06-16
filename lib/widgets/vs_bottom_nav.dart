import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_theme.dart';

class VsBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const VsBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
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
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            key: ValueKey(isActive),
                            color: isActive ? AppColors.accent : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _label(l10n, i),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? AppColors.accent : AppColors.textSecondary,
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
