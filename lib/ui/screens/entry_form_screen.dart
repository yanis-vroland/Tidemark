import 'package:flutter/material.dart';

import '../../entries/entry_repository.dart';

/// Saisie d'une entrée (spec 001). Se ferme après l'enregistrement ou l'abandon.
class EntryFormScreen extends StatelessWidget {
  const EntryFormScreen({super.key, required this.repository});

  final EntryRepository repository;

  @override
  Widget build(BuildContext context) =>
      throw UnimplementedError('EntryFormScreen');
}
