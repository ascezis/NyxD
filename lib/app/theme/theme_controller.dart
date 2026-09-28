import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { light, dark, scheduled }

class ThemeController extends ChangeNotifier {
  static const _modeKey = 'theme.mode';
  static const _darkFromKey = 'theme.darkFromMinutes';
  static const _lightFromKey = 'theme.lightFromMinutes';
  static const _inactivityTimeoutKey = 'security.inactivityTimeoutSeconds';

  ThemePreference preference = ThemePreference.scheduled;
  int darkFromMinutes = 20 * 60;
  int lightFromMinutes = 7 * 60;
  int inactivityTimeoutSeconds = 40;
  Timer? _timer;

  ThemeMode get themeMode {
    return switch (preference) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.scheduled =>
        isDarkAt(DateTime.now()) ? ThemeMode.dark : ThemeMode.light,
    };
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedMode = preferences.getString(_modeKey);
    preference = ThemePreference.values.firstWhere(
      (value) => value.name == storedMode,
      orElse: () => ThemePreference.scheduled,
    );
    darkFromMinutes = preferences.getInt(_darkFromKey) ?? darkFromMinutes;
    lightFromMinutes = preferences.getInt(_lightFromKey) ?? lightFromMinutes;
    inactivityTimeoutSeconds =
        preferences.getInt(_inactivityTimeoutKey) ?? inactivityTimeoutSeconds;
    _scheduleRefresh();
    notifyListeners();
  }

  Future<void> setPreference(ThemePreference value) async {
    preference = value;
    _scheduleRefresh();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modeKey, value.name);
  }

  Future<void> setSchedule({
    required int darkFrom,
    required int lightFrom,
  }) async {
    darkFromMinutes = darkFrom;
    lightFromMinutes = lightFrom;
    _scheduleRefresh();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setInt(_darkFromKey, darkFrom),
      preferences.setInt(_lightFromKey, lightFrom),
    ]);
  }

  Future<void> setInactivityTimeout(int seconds) async {
    inactivityTimeoutSeconds = seconds.clamp(30, 900);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_inactivityTimeoutKey, inactivityTimeoutSeconds);
  }

  bool isDarkAt(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    if (darkFromMinutes == lightFromMinutes) return true;
    if (darkFromMinutes < lightFromMinutes) {
      return minutes >= darkFromMinutes && minutes < lightFromMinutes;
    }
    return minutes >= darkFromMinutes || minutes < lightFromMinutes;
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    if (preference != ThemePreference.scheduled) return;
    final now = DateTime.now();
    final candidates = [darkFromMinutes, lightFromMinutes].map((minutes) {
      var boundary = DateTime(
        now.year,
        now.month,
        now.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (!boundary.isAfter(now)) {
        boundary = boundary.add(const Duration(days: 1));
      }
      return boundary;
    }).toList()..sort();
    _timer = Timer(candidates.first.difference(now), () {
      notifyListeners();
      _scheduleRefresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
