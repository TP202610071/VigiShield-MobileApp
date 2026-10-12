import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de la app en sus dos modos.
///
/// Siguen siendo `AppColors.background`, `AppColors.accent`, etc., pero ya no
/// son constantes: devuelven el color del modo activo. El modo lo cambia
/// [TemaProvider] con [usarModoClaro] y luego reconstruye toda la app.
class AppColors {
  AppColors._();

  static _Paleta _p = _Paleta.oscura;

  static bool get esClaro => identical(_p, _Paleta.clara);
  static void usarModoClaro(bool claro) => _p = claro ? _Paleta.clara : _Paleta.oscura;

  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceElevated => _p.surfaceElevated;
  static Color get border => _p.border;

  static Color get accent => _p.accent;
  static Color get accentDark => _p.accentDark;

  /// Texto e iconos sobre el color de acento: negro en el oscuro, blanco en el claro.
  static Color get onAccent => esClaro ? Colors.white : Colors.black;

  static Color get alertRed => _p.alertRed;
  static Color get safeGreen => _p.safeGreen;
  static Color get warningAmber => _p.warningAmber;

  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMuted => _p.textMuted;
}

class _Paleta {
  final Color background, surface, surfaceElevated, border;
  final Color accent, accentDark;
  final Color alertRed, safeGreen, warningAmber;
  final Color textPrimary, textSecondary, textMuted;

  const _Paleta({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.accent,
    required this.accentDark,
    required this.alertRed,
    required this.safeGreen,
    required this.warningAmber,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  /// El de siempre.
  static const oscura = _Paleta(
    background: Color(0xFF0A0F1E),
    surface: Color(0xFF141C2E),
    surfaceElevated: Color(0xFF1A2540),
    border: Color(0xFF1E2D42),
    accent: Color(0xFF00C2FF),
    accentDark: Color(0xFF0095C4),
    alertRed: Color(0xFFFF3B3B),
    safeGreen: Color(0xFF00E676),
    warningAmber: Color(0xFFFFB300),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8A9BB0),
    textMuted: Color(0xFF3D4F66),
  );

  /// Claro: grises fríos, superficies blancas con borde fino y el mismo azul
  /// de la marca, más profundo para que se lea sobre blanco. Los colores de
  /// estado son más oscuros que en el modo oscuro por la misma razón.
  static const clara = _Paleta(
    background: Color(0xFFF2F4F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFDCE2EA),
    accent: Color(0xFF0077C8),
    accentDark: Color(0xFF005A99),
    alertRed: Color(0xFFD92D2D),
    safeGreen: Color(0xFF0E8F47),
    warningAmber: Color(0xFFB86E00),
    textPrimary: Color(0xFF0F1B2D),
    textSecondary: Color(0xFF526175),
    textMuted: Color(0xFFA3AEBC),
  );
}

/// La paleta oscura fija, para lo que siempre va sobre video o fondo negro (la
/// pestaña Cámara): se ve igual en los dos modos, como cualquier visor de video.
class AppColorsOscuros {
  AppColorsOscuros._();

  static const background = Color(0xFF0A0F1E);
  static const surface = Color(0xFF141C2E);
  static const surfaceElevated = Color(0xFF1A2540);
  static const border = Color(0xFF1E2D42);
  static const accent = Color(0xFF00C2FF);
  static const accentDark = Color(0xFF0095C4);
  static const onAccent = Colors.black;
  static const alertRed = Color(0xFFFF3B3B);
  static const safeGreen = Color(0xFF00E676);
  static const warningAmber = Color(0xFFFFB300);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8A9BB0);
  static const textMuted = Color(0xFF3D4F66);
}

class AppTheme {
  AppTheme._();

  /// Tema del modo activo (ver [AppColors.usarModoClaro]).
  static ThemeData get actual => AppColors.esClaro ? _construir(Brightness.light) : _construir(Brightness.dark);

  static ThemeData get dark => _construir(Brightness.dark);

  /// Iconos de la barra de estado según el modo activo.
  static SystemUiOverlayStyle get barraDeEstado =>
      (AppColors.esClaro ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(statusBarColor: Colors.transparent);

  static ThemeData _construir(Brightness brillo) {
    final claro = brillo == Brightness.light;
    final base = claro ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);
    final esquema = claro
        ? ColorScheme.light(
            primary: AppColors.accent,
            surface: AppColors.surface,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
            error: AppColors.alertRed,
            outline: AppColors.border,
          )
        : ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.surface,
            onPrimary: Colors.black,
            onSurface: AppColors.textPrimary,
          );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: esquema,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: (claro ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: claro ? AppColors.textPrimary : AppColors.surfaceElevated,
        contentTextStyle: GoogleFonts.inter(color: claro ? Colors.white : AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      // Transición al abrir pantallas: la de iOS en iPhone y un desvanecido con
      // deslizamiento corto en Android, en vez del zoom por defecto.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle headline(BuildContext context) =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5);

  static TextStyle title(BuildContext context) =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static TextStyle body(BuildContext context) =>
      GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary);

  static TextStyle caption(BuildContext context) =>
      GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary);

  static TextStyle label(BuildContext context) =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8);
}
