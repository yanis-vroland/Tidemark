import 'package:flutter/material.dart';

import 'entries/entry_repository.dart';
import 'ui/screens/entry_list_screen.dart';
import 'ui/theme/tidemark_theme.dart';

void main() {
  // Ouverture de la base chiffrée : implémentée avec la spec 001.
  throw UnimplementedError('main');
}

class TidemarkApp extends StatelessWidget {
  const TidemarkApp({super.key, required this.repository, this.clock});

  final EntryRepository repository;

  /// Date et heure locales ; [DateTime.now] par défaut.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidemark',
      theme: buildTidemarkTheme(Brightness.light),
      darkTheme: buildTidemarkTheme(Brightness.dark),
      home: EntryListScreen(
        repository: repository,
        clock: clock ?? DateTime.now,
      ),
    );
  }
}
