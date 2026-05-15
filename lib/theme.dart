import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}


extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

class LightModeColors {
  // Deep navy base (premium)
  static const primary = Color(0xFF071A2B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF0A3D62);
  static const onSecondary = Color(0xFFFFFFFF);
  // Golden metal (premium)
  static const accent = metalGold;
  // Premium metallic accents
  static const metalGold = Color(0xFFD4AF37);
  static const metalGoldDeep = Color(0xFFB8860B);
  static const metalGoldSoft = Color(0xFFFFF3B0);
  // Slight champagne background for a warmer premium feel
  static const background = Color(0xFFFBFAF6);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF071A2B);
  static const primaryText = Color(0xFF071A2B);
  static const secondaryText = Color(0xFF475569);
  static const hint = Color(0xFF94A3B8);
  static const error = Color(0xFFDC2626);
  static const emergencyRed = Color(0xFFFF3B30);
  // Medical blue palette (Emergency UI)
  static const medicalBlue = Color(0xFF2563EB);
  static const medicalBlueDeep = Color(0xFF1D4ED8);
  static const medicalBlueSoft = Color(0xFFEAF2FF);
  static const cyberDarkBlue = Color(0xFF0D1B2A);
  static const onError = Color(0xFFFFFFFF);
  static const success = Color(0xFF059669);
  static const divider = Color(0xFFE2E8F0);
  static const transparent = Color(0x00000000);
}

class DarkModeColors {
  // Deep navy base (premium)
  static const primary = Color(0xFF071A2B);
  static const onPrimary = Color(0xFFFFFFFF);
  // Gold as secondary for premium accents
  static const secondary = metalGoldDeep;
  static const onSecondary = Color(0xFF071A2B);
  static const accent = metalGold;
  // Premium metallic accents
  static const metalGold = Color(0xFFD4AF37);
  static const metalGoldDeep = Color(0xFFB8860B);
  static const metalGoldSoft = Color(0xFFFFF3B0);
  static const background = Color(0xFF071A2B);
  static const surface = Color(0xFF0B2336);
  static const onSurface = Color(0xFFF8FAFC);
  static const primaryText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFF94A3B8);
  static const hint = Color(0xFF475569);
  static const error = Color(0xFFEF4444);
  static const emergencyRed = Color(0xFFFF3B30);
  // Medical blue palette (Emergency UI)
  static const medicalBlue = Color(0xFF60A5FA);
  static const medicalBlueDeep = Color(0xFF3B82F6);
  static const medicalBlueSoft = Color(0xFF0B2336);
  static const cyberDarkBlue = Color(0xFF0D1B2A);
  static const onError = Color(0xFFFFFFFF);
  static const success = Color(0xFF10B981);
  static const divider = Color(0xFF1E5F8C);
  static const transparent = Color(0x00000000);
}

/// Admin / Cyber dark theme accents (electric blue + neon glow).
///
/// These are *additional* tokens used by the Admin web dashboard without
/// disrupting the existing premium gold palette used in the consumer app.
class AdminCyberColors {
  static const black = Color(0xFF05070C);
  static const panel = Color(0xFF08121E);
  static const panelHi = Color(0xFF0B1B2A);
  static const stroke = Color(0xFF14334D);
  static const text = Color(0xFFEAF2FF);
  static const textDim = Color(0xFF9BB3D3);
  static const electricBlue = Color(0xFF3B82F6);
  static const neonCyan = Color(0xFF22D3EE);
  static const neonViolet = Color(0xFFA78BFA);
  static const danger = Color(0xFFFB7185);
  static const success = Color(0xFF34D399);
}

/// Consumer-side "Learning" palette (ultra-premium dark) for Trainings.
///
/// We reuse the same futuristic aesthetic as Admin, but keep it separated from
/// the general app tokens so we can apply it only to the Training ecosystem.
class LearningCyberColors {
  static const black = Color(0xFF05070C);
  static const bg0 = Color(0xFF05070C);
  static const bg1 = Color(0xFF071326);
  static const panel = Color(0xFF08121E);
  static const panelHi = Color(0xFF0B1B2A);
  static const stroke = Color(0xFF14334D);
  static const text = Color(0xFFEAF2FF);
  static const textDim = Color(0xFF9BB3D3);
  static const electricBlue = Color(0xFF3B82F6);
  static const neonCyan = Color(0xFF22D3EE);
  static const neonViolet = Color(0xFFA78BFA);
  static const danger = Color(0xFFFB7185);
  static const success = Color(0xFF34D399);
}

/// User-side Events ecosystem palette (ultra-premium dark: black + electric blue + neon cyan).
///
/// Kept separate from Admin/Learning so we can iterate without breaking other modules.
class EventsCyberColors {
  static const black = Color(0xFF05070C);
  static const bg0 = Color(0xFF05070C);
  static const bg1 = Color(0xFF06152B);
  static const panel = Color(0xFF08121E);
  static const panelHi = Color(0xFF0B1B2A);
  static const stroke = Color(0xFF14334D);
  static const text = Color(0xFFEAF2FF);
  static const textDim = Color(0xFF9BB3D3);
  static const electricBlue = Color(0xFF3B82F6);
  static const neonCyan = Color(0xFF22D3EE);
  static const neonViolet = Color(0xFFA78BFA);
  static const danger = Color(0xFFFB7185);
  static const success = Color(0xFF34D399);
}

class EventsCyberGradients {
  static LinearGradient background() => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [EventsCyberColors.bg0, EventsCyberColors.bg1],
      );

  static LinearGradient glowBlue() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [EventsCyberColors.electricBlue, EventsCyberColors.neonCyan],
      );

  static LinearGradient cinematicScrim() => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.black.withValues(alpha: 0.82), Colors.black.withValues(alpha: 0.35), Colors.transparent],
        stops: const [0, 0.55, 1],
      );
}

/// Institutional palette (clean navy + civic blue).
///
/// Used in modules that need a more “institutional” look (less premium-gold).
class InstitutionalColors {
  static const navy = Color(0xFF0B1F36);
  static const navy2 = Color(0xFF123A63);
  static const civicBlue = Color(0xFF1D4ED8);
  static const civicBlueSoft = Color(0xFFDBEAFE);
  static const ink = Color(0xFF0F172A);
}

class LearningCyberGradients {
  static LinearGradient background() => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [LearningCyberColors.bg0, LearningCyberColors.bg1],
      );

  static LinearGradient glowBlue() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [LearningCyberColors.electricBlue, LearningCyberColors.neonCyan],
      );
}

class AdminCyberGradients {
  static LinearGradient glowBlue() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AdminCyberColors.electricBlue,
          AdminCyberColors.neonCyan,
        ],
      );

  static LinearGradient glowViolet() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AdminCyberColors.neonViolet,
          AdminCyberColors.electricBlue,
        ],
      );
}

/// Premium gradients (gold metal)
class AppPremiumGradients {
  static LinearGradient thixGold(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.tertiary,
          scheme.secondary,
        ],
      );

  static LinearGradient thixNavyToGold(ColorScheme scheme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary,
          scheme.tertiary,
        ],
      );
}

/// Emergency (SOS) premium dark template tokens.
///
/// This palette intentionally stays dark even in light theme to match
/// the URGENT overlay template (better contrast for the central SOS).
class EmergencyUrgentColors {
  static const bg0 = Color(0xFF050A14);
  static const bg1 = Color(0xFF071326);
  static const panel = Color(0xFF0B1B2A);
  static const card = Color(0xFF0E2234);
  static const stroke = Color(0xFF163A57);
  static const text = Color(0xFFF3F6FF);
  static const textDim = Color(0xFFA9B8D6);

  static const danger = DarkModeColors.emergencyRed;
  static const medicalBlue = Color(0xFF2F7DFF);
  static const safetyGreen = Color(0xFF22C55E);
  static const fireOrange = Color(0xFFFF6A3D);
  static const violet = Color(0xFFA78BFA);
  static const amber = Color(0xFFFBBF24);
  static const cyan = Color(0xFF22D3EE);

  static Color scrim() => const Color(0xFF00040A).withValues(alpha: 0.62);
}

class EmergencyUrgentGradients {
  static LinearGradient background() => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          EmergencyUrgentColors.bg0,
          EmergencyUrgentColors.bg1,
        ],
      );

  static LinearGradient panel() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          EmergencyUrgentColors.panel,
          EmergencyUrgentColors.card,
        ],
      );
}

/// Emergency form (medical/light) tokens used by action sheets like Blood request.
///
/// The SOS overlay stays dark (EmergencyUrgentColors) but forms should remain
/// bright, medical, and highly readable.
class EmergencyMedicalSheetColors {
  // Light, clean medical background.
  static const bg0 = Color(0xFFF3F8FF);
  static const bg1 = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const stroke = Color(0xFFE2ECFA);
  static const text = LightModeColors.primary;
  static const textDim = Color(0xFF5B6B82);
  static const medicalBlue = LightModeColors.medicalBlue;
  static const medicalBlueSoft = LightModeColors.medicalBlueSoft;
}

class EmergencyMedicalSheetGradients {
  static LinearGradient background() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [EmergencyMedicalSheetColors.bg0, EmergencyMedicalSheetColors.bg1],
      );
}

/// Urgency scale colors (used in medical forms).
class EmergencyUrgencyScaleColors {
  static const stable = Color(0xFF22C55E);
  static const moderate = Color(0xFFFBBF24);
  static const urgent = Color(0xFFFF7A3D);
  static const critical = DarkModeColors.emergencyRed;
}

/// Font size constants
class FontSizes {
  static const double headlineLarge = 20;
  static const double headlineMedium = 26.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 17.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelLarge = 15.0;
  static const double labelMedium = 13.0;
  static const double labelSmall = 11.0;
}

// =============================================================================
// THEMES
// =============================================================================

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: LightModeColors.primary,
        onPrimary: LightModeColors.onPrimary,
        secondary: LightModeColors.metalGoldDeep,
        onSecondary: LightModeColors.onSurface,
        tertiary: LightModeColors.metalGold,
        onTertiary: LightModeColors.onSurface,
        error: LightModeColors.error,
        onError: LightModeColors.onError,
        surface: LightModeColors.surface,
        onSurface: LightModeColors.onSurface,
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightModeColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: LightModeColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: LightModeColors.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      cardTheme: CardThemeData(
        color: LightModeColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(
            color: LightModeColors.divider,
            width: 1,
          ),
        ),
      ),
      textTheme: _buildTextTheme(LightModeColors.primaryText),
    );

ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: DarkModeColors.primary,
        onPrimary: DarkModeColors.onPrimary,
        secondary: DarkModeColors.metalGoldDeep,
        onSecondary: DarkModeColors.onSecondary,
        tertiary: DarkModeColors.metalGold,
        onTertiary: DarkModeColors.onSecondary,
        error: DarkModeColors.error,
        onError: DarkModeColors.onError,
        surface: DarkModeColors.surface,
        onSurface: DarkModeColors.onSurface,
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkModeColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DarkModeColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: DarkModeColors.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      cardTheme: CardThemeData(
        color: DarkModeColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(
            color: DarkModeColors.divider,
            width: 1,
          ),
        ),
      ),
      textTheme: _buildTextTheme(DarkModeColors.primaryText),
    );

TextTheme _buildTextTheme(Color textColor) {
  return TextTheme(
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: textColor,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: textColor,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: textColor,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: textColor,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: textColor,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: textColor,
    ),
    labelSmall: GoogleFonts.plusJakartaSans(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: textColor,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: textColor,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: textColor,
    ),
  );
}
