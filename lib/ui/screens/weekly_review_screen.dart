import 'package:flutter/material.dart';

import '../../entries/entry_repository.dart';
import '../../review/review_narrator.dart';

/// Bilan de la semaine (spec 006), ouvert depuis la liste sur la semaine en cours.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({
    super.key,
    required this.repository,
    required this.narrator,
    required this.clock,
  });

  final EntryRepository repository;

  /// Mise en mots et mémoire des textes (RM54), partagée par toute l'app.
  final ReviewNarrator narrator;

  /// Date et heure locales : semaine en cours.
  final DateTime Function() clock;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
