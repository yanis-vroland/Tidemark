import 'package:flutter/material.dart';

import '../../entries/entry_repository.dart';

/// Liste des entrées, écran d'accueil (spec 001).
class EntryListScreen extends StatelessWidget {
  const EntryListScreen({
    super.key,
    required this.repository,
    required this.clock,
  });

  final EntryRepository repository;

  /// Date et heure locales, pour les intertitres « Aujourd'hui » et « Hier ».
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) =>
      throw UnimplementedError('EntryListScreen');
}
