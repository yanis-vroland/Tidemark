import 'package:flutter/material.dart';

import '../phone_dialer.dart';

/// Écran d'aide fixe (glossaire : `HelpScreen`, spec 002, RM7) : jamais généré.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.dialer});

  final PhoneDialer dialer;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
