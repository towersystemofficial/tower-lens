import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppDisplayMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const AppDisplayMode(this.label);
  final String label;
}

enum AppPalette {
  prismatic('Palette 1', Color(0xFF8B7CFF)),
  aurora('Palette 2', Color(0xFF38D6C5)),
  ember('Palette 3', Color(0xFFE58A72)),
  twilight('Palette 4', Color(0xFFB66BE0)),
  device('Match device wallpaper', Color(0xFF8B7CFF));

  const AppPalette(this.label, this.seedColor);
  final String label;
  final Color seedColor;
}

enum GlassLevel {
  none('None', 0),
  minimal('Minimal', 0.25),
  soft('Soft', 0.5),
  balanced('Balanced', 0.75),
  strong('Strong', 1);

  const GlassLevel(this.label, this.intensity);
  final String label;
  final double intensity;
}

enum AppTextSize {
  small('Small', 0.9),
  standard('Default', 1),
  large('Large', 1.12),
  larger('Larger', 1.25),
  largest('Largest', 1.4);

  const AppTextSize(this.label, this.multiplier);
  final String label;
  final double multiplier;
}

enum MotionLevel {
  none('No motion', 0),
  minimal('Minimal', 0.2),
  subtle('Subtle', 0.4),
  dynamic('Dynamic', 0.7);

  const MotionLevel(this.label, this.intensity);
  final String label;
  final double intensity;
}

class AppearanceSettings extends ChangeNotifier {
  static const _displayModeKey = 'appearance_display_mode';
  static const _paletteKey = 'appearance_palette';
  static const _glassLevelKey = 'appearance_glass_level';
  static const _textSizeKey = 'appearance_text_size';
  static const _motionLevelKey = 'appearance_motion_level';

  AppDisplayMode _displayMode = AppDisplayMode.system;
  AppPalette _palette = AppPalette.prismatic;
  GlassLevel _glassLevel = GlassLevel.balanced;
  AppTextSize _textSize = AppTextSize.standard;
  MotionLevel _motionLevel = MotionLevel.subtle;

  AppDisplayMode get displayMode => _displayMode;
  AppPalette get palette => _palette;
  GlassLevel get glassLevel => _glassLevel;
  AppTextSize get textSize => _textSize;
  MotionLevel get motionLevel => _motionLevel;

  ThemeMode get themeMode => switch (_displayMode) {
        AppDisplayMode.system => ThemeMode.system,
        AppDisplayMode.light => ThemeMode.light,
        AppDisplayMode.dark => ThemeMode.dark,
      };

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _displayMode = _readEnum(
      AppDisplayMode.values,
      preferences.getString(_displayModeKey),
      AppDisplayMode.system,
    );
    _palette = _readEnum(
      AppPalette.values,
      preferences.getString(_paletteKey),
      AppPalette.prismatic,
    );
    _glassLevel = _readEnum(
      GlassLevel.values,
      preferences.getString(_glassLevelKey),
      GlassLevel.balanced,
    );
    _textSize = _readEnum(
      AppTextSize.values,
      preferences.getString(_textSizeKey),
      AppTextSize.standard,
    );
    _motionLevel = _readEnum(
      MotionLevel.values,
      preferences.getString(_motionLevelKey),
      MotionLevel.subtle,
    );
    notifyListeners();
  }

  Future<void> setDisplayMode(AppDisplayMode value) async {
    _displayMode = value;
    notifyListeners();
    await _save(_displayModeKey, value.name);
  }

  Future<void> setPalette(AppPalette value) async {
    _palette = value;
    notifyListeners();
    await _save(_paletteKey, value.name);
  }

  Future<void> setGlassLevel(GlassLevel value) async {
    _glassLevel = value;
    notifyListeners();
    await _save(_glassLevelKey, value.name);
  }

  Future<void> setTextSize(AppTextSize value) async {
    _textSize = value;
    notifyListeners();
    await _save(_textSizeKey, value.name);
  }

  Future<void> setMotionLevel(MotionLevel value) async {
    _motionLevel = value;
    notifyListeners();
    await _save(_motionLevelKey, value.name);
  }

  Future<void> _save(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }

  T _readEnum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

@immutable
class GlassStyle extends ThemeExtension<GlassStyle> {
  const GlassStyle({
    required this.intensity,
    required this.blurSigma,
    required this.surfaceOpacity,
    required this.glowOpacity,
  });

  factory GlassStyle.fromLevel(GlassLevel level) {
    final intensity = level.intensity;
    return GlassStyle(
      intensity: intensity,
      // "Glass" is a crisp holographic coating, never frosted backdrop blur.
      blurSigma: 0,
      surfaceOpacity: level == GlassLevel.none ? 1 : 0.92 - (0.12 * intensity),
      glowOpacity: 0.32 * intensity,
    );
  }

  final double intensity;
  final double blurSigma;
  final double surfaceOpacity;
  final double glowOpacity;

  @override
  GlassStyle copyWith({
    double? intensity,
    double? blurSigma,
    double? surfaceOpacity,
    double? glowOpacity,
  }) {
    return GlassStyle(
      intensity: intensity ?? this.intensity,
      blurSigma: blurSigma ?? this.blurSigma,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      glowOpacity: glowOpacity ?? this.glowOpacity,
    );
  }

  @override
  GlassStyle lerp(GlassStyle? other, double t) {
    if (other == null) return this;
    return GlassStyle(
      intensity: lerpDouble(intensity, other.intensity, t),
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t),
      surfaceOpacity: lerpDouble(surfaceOpacity, other.surfaceOpacity, t),
      glowOpacity: lerpDouble(glowOpacity, other.glowOpacity, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

@immutable
class MotionStyle extends ThemeExtension<MotionStyle> {
  const MotionStyle({required this.intensity});

  factory MotionStyle.fromLevel(MotionLevel level) =>
      MotionStyle(intensity: level.intensity);

  final double intensity;

  Duration get transitionDuration =>
      intensity == 0
          ? Duration.zero
          : Duration(milliseconds: 120 + (180 * intensity).round());

  @override
  MotionStyle copyWith({double? intensity}) =>
      MotionStyle(intensity: intensity ?? this.intensity);

  @override
  MotionStyle lerp(MotionStyle? other, double t) {
    if (other == null) return this;
    return MotionStyle(
      intensity: GlassStyle.lerpDouble(intensity, other.intensity, t),
    );
  }
}
