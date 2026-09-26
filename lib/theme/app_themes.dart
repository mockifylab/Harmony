/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_colors.dart';

ThemeMode themeMode = getThemeMode(themeModeSetting);
Brightness brightness = getBrightnessFromThemeMode(themeMode);

Brightness getBrightnessFromThemeMode(ThemeMode themeMode) {
  final themeBrightnessMapping = {
    ThemeMode.light: Brightness.light,
    ThemeMode.dark: Brightness.dark,
    ThemeMode.system:
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
  };

  return themeBrightnessMapping[themeMode] ?? Brightness.dark;
}

ThemeMode getThemeMode(int themeModeIndex) {
  const themeModes = ThemeMode.values;
  if (themeModeIndex >= 0 && themeModeIndex < themeModes.length) {
    return themeModes[themeModeIndex];
  }
  return ThemeMode.system;
}

ColorScheme getAppColorScheme(
  ColorScheme? lightColorScheme,
  ColorScheme? darkColorScheme,
) {
  final selectedScheme = (brightness == Brightness.light)
      ? lightColorScheme
      : darkColorScheme;

  // The effective accent: the wallpaper tint when the user opted into system
  // color, otherwise their saved pick. Harmony green is only the default.
  final accentColor = useSystemColor.value && selectedScheme != null
      ? selectedScheme.primary
      : primaryColorSetting;
  final isHarmonyGreen = accentColor == SpotifyColors.green;

  // Tonal derivatives of a custom accent keep on-colors and containers
  // legible for every swatch without giving up the fixed Harmony surfaces.
  final accentScheme = ColorScheme.fromSeed(
    seedColor: isHarmonyGreen
        ? (brightness == Brightness.light
              ? SpotifyColors.deepGreen
              : SpotifyColors.green)
        : accentColor,
    brightness: brightness,
  );

  if (brightness == Brightness.light) {
    const creamBg = Color(0xFFF3F0E7);
    const lightCard = Color(0xFFEBE7DC);
    const lightElevated = Color(0xFFE4E0D4);
    const ink = Color(0xFF22312A);

    return ColorScheme(
      brightness: Brightness.light,
      primary: isHarmonyGreen ? SpotifyColors.deepGreen : accentScheme.primary,
      onPrimary: isHarmonyGreen ? SpotifyColors.white : accentScheme.onPrimary,
      secondary: ink,
      onSecondary: SpotifyColors.white,
      tertiary: accentColor,
      onTertiary: SpotifyColors.white,
      error: const Color(0xFFB3111F),
      onError: SpotifyColors.white,
      surface: creamBg,
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF5A6156),
      primaryContainer: isHarmonyGreen
          ? SpotifyColors.green.withValues(alpha: 0.18)
          : accentScheme.primaryContainer,
      onPrimaryContainer: isHarmonyGreen
          ? SpotifyColors.deepGreen
          : accentScheme.onPrimaryContainer,
      secondaryContainer: lightElevated,
      onSecondaryContainer: ink,
      tertiaryContainer: accentColor.withValues(alpha: 0.22),
      onTertiaryContainer: ink,
      surfaceContainerLowest: creamBg,
      surfaceContainerLow: lightCard,
      surfaceContainer: lightCard,
      surfaceContainerHigh: lightCard,
      surfaceContainerHighest: lightElevated,
      outline: const Color(0xFFB9B4A6),
      outlineVariant: const Color(0xFFD6D1C4),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: ink,
      onInverseSurface: creamBg,
      inversePrimary: SpotifyColors.green,
    );
  }

  final isPureBlack = usePureBlackColor.value;
  const bg = Color(0xFF07110C);
  final card = isPureBlack ? const Color(0xFF0A0A0A) : SpotifyColors.card;
  final elevated = isPureBlack
      ? const Color(0xFF121212)
      : SpotifyColors.elevated;

  return ColorScheme(
    brightness: Brightness.dark,
    primary: isHarmonyGreen ? SpotifyColors.green : accentScheme.primary,
    onPrimary: isHarmonyGreen ? Colors.black : accentScheme.onPrimary,
    secondary: SpotifyColors.white,
    onSecondary: Colors.black,
    tertiary: accentColor,
    onTertiary: SpotifyColors.white,
    error: const Color(0xFFE91429),
    onError: SpotifyColors.white,
    surface: bg,
    onSurface: SpotifyColors.white,
    onSurfaceVariant: SpotifyColors.muted,
    primaryContainer: isHarmonyGreen
        ? SpotifyColors.green.withValues(alpha: 0.18)
        : accentScheme.primaryContainer,
    onPrimaryContainer: isHarmonyGreen
        ? SpotifyColors.green
        : accentScheme.onPrimaryContainer,
    secondaryContainer: elevated,
    onSecondaryContainer: SpotifyColors.white,
    tertiaryContainer: accentColor.withValues(alpha: 0.22),
    onTertiaryContainer: SpotifyColors.white,
    surfaceContainerLowest: bg,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: card,
    surfaceContainerHighest: elevated,
    outline: const Color(0xFF3E3E3E),
    outlineVariant: const Color(0xFF2A2A2A),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: SpotifyColors.white,
    onInverseSurface: Colors.black,
    inversePrimary: SpotifyColors.green,
  );
}

/// Frosted-glass fill for the floating chrome (navbar, mini player, profile
/// pill). Opaque enough to stay readable over scrolling content.
Color getGlassSurfaceColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xB3222222)
      : const Color(0xE6F0F5E9);
}

/// Stroke for the floating glass chrome; follows the active accent.
Color getGlassBorderColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.16)
      : colorScheme.primary.withValues(alpha: 0.38);
}

/// Outer glow of the floating glass chrome.
Color getGlassShadowColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.10);
}

/// Frosted fill of the settings drawer; deeper/moodier than the floating
/// chrome glass, cream in light mode.
Color getSettingsGlassColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xB207110C)
      : const Color(0xE6F0F5E9);
}

/// Surface fill of the Harmony list cards (songs, playlists, recaps).
Color getHarmonyCardColor(ColorScheme colorScheme) {
  return colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
}

/// Subtle accent stroke of the Harmony list cards.
Border getHarmonyCardBorder(ColorScheme colorScheme) {
  return Border.all(color: colorScheme.primary.withValues(alpha: 0.16));
}

/// Restrained accent glow of the Harmony list cards.
List<BoxShadow> getHarmonyCardShadow(ColorScheme colorScheme) {
  return [
    BoxShadow(
      color: colorScheme.primary.withValues(alpha: 0.10),
      blurRadius: 14,
    ),
  ];
}

/// Accent stroke of the card whose song is currently playing. Same width as
/// [getHarmonyCardBorder], so becoming the current card never shifts layout.
Border getHarmonyActiveCardBorder(ColorScheme colorScheme) {
  return Border.all(color: colorScheme.primary.withValues(alpha: 0.55));
}

/// Slightly stronger accent glow for the card whose song is currently playing.
List<BoxShadow> getHarmonyActiveCardShadow(ColorScheme colorScheme) {
  return [
    BoxShadow(
      color: colorScheme.primary.withValues(alpha: 0.22),
      blurRadius: 18,
    ),
  ];
}

/// Chrome of the app's circular action buttons: the same frosted fill, accent
/// stroke and soft glow as the Mini Player's close button. [active] keeps the
/// accent visible for toggles by tinting the fill instead of replacing it.
ButtonStyle getHarmonyCircleActionStyle(
  ColorScheme colorScheme, {
  bool active = false,
}) {
  return IconButton.styleFrom(
    backgroundColor: active
        ? colorScheme.primary.withValues(alpha: 0.18)
        : getGlassSurfaceColor(colorScheme),
    foregroundColor: colorScheme.primary,
    side: BorderSide(
      color: active
          ? colorScheme.primary.withValues(alpha: 0.55)
          : getGlassBorderColor(colorScheme),
    ),
    shadowColor: getGlassShadowColor(colorScheme),
    elevation: 6,
    shape: const CircleBorder(),
  );
}

ThemeData getAppTheme(ColorScheme colorScheme) {
  final base = colorScheme.brightness == Brightness.light
      ? ThemeData.light()
      : ThemeData.dark();

  final bgColor = colorScheme.surface;
  final cardBgColor = colorScheme.surfaceContainerLow;

  return ThemeData(
    textTheme: base.textTheme.apply(
      fontFamily: 'sans-serif',
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: bgColor,
    colorScheme: colorScheme,
    cardColor: cardBgColor,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bgColor,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
        letterSpacing: -0.4,
      ),
      toolbarHeight: 56,
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: colorScheme.onSurface,
      iconColor: colorScheme.onSurfaceVariant,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      year2023: false,
      trackHeight: 4,
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.outline,
      thumbColor: colorScheme.onSurface,
      overlayColor: colorScheme.primary.withValues(alpha: 0.16),
      thumbSize: WidgetStateProperty.all(const Size(10, 10)),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      isDense: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // One central button language: the Harmony card radius instead of the
    // M3 capsule, with the dynamic accent outline derived from the scheme.
    // Circular buttons (IconButton and friends) are untouched.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: colorScheme.primary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: colorScheme.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.onSurface, size: 24);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: colorScheme.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      closeIconColor: colorScheme.onSurface,
      contentTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      actionTextColor: colorScheme.primary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: true,
  );
}
