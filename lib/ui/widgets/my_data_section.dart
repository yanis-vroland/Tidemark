import 'package:flutter/material.dart';

import '../../export/journal_export.dart';
import '../../wipe/journal_wiper.dart';

/// Ce que la section « Mes données » des Réglages déclenche (spec 005) : l'export
/// et la suppression totale.
class DataActions {
  const DataActions({required this.export, required this.wiper});

  final JournalExport export;
  final JournalWiper wiper;
}

/// Section « Mes données » des Réglages (spec 005, CA1 à CA14).
class MyDataSection extends StatefulWidget {
  const MyDataSection({super.key, required this.actions});

  final DataActions actions;

  @override
  State<MyDataSection> createState() => _MyDataSectionState();
}

class _MyDataSectionState extends State<MyDataSection> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
