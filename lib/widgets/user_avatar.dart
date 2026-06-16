import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/server_config_provider.dart';

/// Circular user avatar — shows the uploaded photo, falling back to the user's
/// first initial. Reused on the dashboard, settings and profile screens.
class UserAvatar extends StatelessWidget {
  final double size;
  final double fontSize;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.size = 36,
    this.fontSize = 14,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final base = context.watch<ServerConfigProvider>().serverUrl;
    final url = user?.avatarUrl(base);
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name.substring(0, 1).toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: AppColors.accent.withOpacity(0.3))
            : null,
      ),
      child: url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => _initials(initial),
              loadingBuilder: (ctx, child, progress) =>
                  progress == null ? child : _initials(initial),
            )
          : _initials(initial),
    );
  }

  Widget _initials(String initial) => Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      );
}
