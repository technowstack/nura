import 'package:flutter/material.dart';

ThemeMode themeModeFromSetting(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};
