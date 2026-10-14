import 'package:flutter/material.dart';

import 'ui/theme/tidemark_theme.dart';
import 'ui/theme/tidemark_tokens.dart';

void main() {
  runApp(const TidemarkApp());
}

class TidemarkApp extends StatelessWidget {
  const TidemarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidemark',
      theme: buildTidemarkTheme(Brightness.light),
      darkTheme: buildTidemarkTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}

/// Écran d'accueil provisoire du socle : il sera remplacé par la liste des entrées
/// (spec du lot E).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TidemarkSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: TidemarkSpacing.space8),
              Text('Tidemark', style: text.displaySmall),
            ],
          ),
        ),
      ),
    );
  }
}
