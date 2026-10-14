import 'package:flutter/material.dart';

import '../../settings/settings_repository.dart';

/// Écran des réglages (glossaire : `SettingsScreen`, spec 002).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsRepository settings;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
