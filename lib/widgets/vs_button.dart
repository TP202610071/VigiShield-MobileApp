import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

enum VsButtonVariant { primary, secondary, danger }

class VsButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final VsButtonVariant variant;
  final double? width;
  final IconData? icon;

  const VsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = VsButtonVariant.primary,
    this.width,
    this.icon,
  });

  @override
  State<VsButton> createState() => _VsButtonState();
}

class _VsButtonState extends State<VsButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _bg {
    if (widget.onPressed == null && !widget.isLoading) return AppColors.border;
    return switch (widget.variant) {
      VsButtonVariant.primary => AppColors.accent,
      VsButtonVariant.secondary => Colors.transparent,
      VsButtonVariant.danger => AppColors.alertRed,
    };
  }

  Color get _fg {
    if (widget.onPressed == null && !widget.isLoading) return AppColors.textMuted;
    return switch (widget.variant) {
      VsButtonVariant.primary => Colors.black,
      VsButtonVariant.secondary => AppColors.accent,
      VsButtonVariant.danger => Colors.white,
    };
  }

  Border? get _border => widget.variant == VsButtonVariant.secondary
      ? Border.all(color: AppColors.accent, width: 1.5)
      : null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => _controller.reverse() : null,
      onTapUp: widget.onPressed != null
          ? (_) async {
              await _controller.forward();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.width,
          height: 52,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(14),
            border: _border,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: _fg, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _fg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
