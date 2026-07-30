import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/theme/appearance_settings.dart';

void main() {
  test('appearance defaults match the agreed visual system', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppearanceSettings();

    await settings.load();

    expect(settings.displayMode, AppDisplayMode.system);
    expect(settings.palette, AppPalette.prismatic);
    expect(settings.glassLevel, GlassLevel.balanced);
    expect(settings.textSize, AppTextSize.standard);
    expect(settings.motionLevel, MotionLevel.subtle);
  });

  test('appearance choices persist across settings instances', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppearanceSettings();
    await settings.load();

    await settings.setDisplayMode(AppDisplayMode.light);
    await settings.setPalette(AppPalette.aurora);
    await settings.setGlassLevel(GlassLevel.none);
    await settings.setTextSize(AppTextSize.largest);
    await settings.setMotionLevel(MotionLevel.dynamic);

    final restored = AppearanceSettings();
    await restored.load();
    expect(restored.themeMode, ThemeMode.light);
    expect(restored.palette, AppPalette.aurora);
    expect(restored.glassLevel, GlassLevel.none);
    expect(restored.textSize, AppTextSize.largest);
    expect(restored.motionLevel, MotionLevel.dynamic);
  });

  test('theme extensions expose scalable glass and motion values', () {
    final noGlass = GlassStyle.fromLevel(GlassLevel.none);
    final strongGlass = GlassStyle.fromLevel(GlassLevel.strong);
    final noMotion = MotionStyle.fromLevel(MotionLevel.none);
    final dynamicMotion = MotionStyle.fromLevel(MotionLevel.dynamic);

    expect(noGlass.blurSigma, 0);
    expect(noGlass.surfaceOpacity, 1);
    expect(strongGlass.blurSigma, greaterThan(noGlass.blurSigma));
    expect(strongGlass.glowOpacity, greaterThan(0));
    expect(noMotion.transitionDuration, Duration.zero);
    expect(dynamicMotion.transitionDuration, greaterThan(Duration.zero));
  });
}
