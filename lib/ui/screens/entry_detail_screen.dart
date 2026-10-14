import 'package:flutter/material.dart';

import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';

/// Détail d'une entrée et sa suppression (spec 001).
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.repository,
  });

  final Entry entry;
  final EntryRepository repository;

  @override
  Widget build(BuildContext context) =>
      throw UnimplementedError('EntryDetailScreen');
}
