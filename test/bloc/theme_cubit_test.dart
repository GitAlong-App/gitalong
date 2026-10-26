import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/app_constants.dart';
import 'package:gitalong/presentation/bloc/theme/theme_cubit.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'fakes.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('theme_cubit_test');
    Hive.init(dir.path);
    // Pre-open so the cubit's own openBox resolves immediately.
    box = await Hive.openBox(AppConstants.settingsBox);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<ThemeCubit> loaded() async {
    final cubit = ThemeCubit();
    await settle();
    return cubit;
  }

  test('defaults to the system theme when nothing is stored', () async {
    final cubit = await loaded();
    expect(cubit.state, ThemeMode.system);
    await cubit.close();
  });

  test('restores a persisted dark theme', () async {
    await box.put(AppConstants.themeKey, 'dark');
    final cubit = await loaded();
    expect(cubit.state, ThemeMode.dark);
    await cubit.close();
  });

  test('an unknown stored value falls back to system', () async {
    await box.put(AppConstants.themeKey, 'sepia');
    final cubit = await loaded();
    expect(cubit.state, ThemeMode.system);
    await cubit.close();
  });

  test('setThemeMode emits and persists', () async {
    final cubit = await loaded();
    await cubit.setThemeMode(ThemeMode.light);
    expect(cubit.state, ThemeMode.light);
    expect(box.get(AppConstants.themeKey), 'light');
    await cubit.close();
  });

  test('toggle: system -> dark -> light', () async {
    final cubit = await loaded();
    await cubit.toggle();
    expect(cubit.state, ThemeMode.dark);
    expect(box.get(AppConstants.themeKey), 'dark');
    await cubit.toggle();
    expect(cubit.state, ThemeMode.light);
    expect(box.get(AppConstants.themeKey), 'light');
    await cubit.close();
  });
}
