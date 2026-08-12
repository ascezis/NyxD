import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/app/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('scheduled theme works across midnight', () {
    final controller = ThemeController();
    addTearDown(controller.dispose);

    expect(controller.isDarkAt(DateTime(2026, 1, 1, 21)), isTrue);
    expect(controller.isDarkAt(DateTime(2026, 1, 2, 3)), isTrue);
    expect(controller.isDarkAt(DateTime(2026, 1, 2, 12)), isFalse);
  });

  test('theme preference and schedule persist', () async {
    final first = ThemeController();
    await first.setPreference(ThemePreference.dark);
    await first.setSchedule(darkFrom: 18 * 60 + 30, lightFrom: 8 * 60);
    await first.setInactivityTimeout(120);
    first.dispose();

    final restored = ThemeController();
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.preference, ThemePreference.dark);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.darkFromMinutes, 18 * 60 + 30);
    expect(restored.lightFromMinutes, 8 * 60);
    expect(restored.inactivityTimeoutSeconds, 120);
  });
}
