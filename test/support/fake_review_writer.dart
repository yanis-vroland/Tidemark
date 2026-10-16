import 'dart:async';

import 'package:tidemark/review/review_writer.dart';
import 'package:tidemark/review/weekly_review.dart';

/// Rédacteur factice, déterministe, pour les tests et la CI : il n'exécute aucun
/// modèle. Il rend la sortie choisie par le test et enregistre ce qu'il reçoit
/// (spec 006, « Données »).
class FakeReviewWriter implements ReviewWriter {
  FakeReviewWriter({
    String? output,
    ReviewDraft? draft,
    this.delay = Duration.zero,
    this.hang = false,
  }) : draft = draft ?? RawReview(output ?? jsonText(validReviewText));

  /// Ce que rend chaque appel ; modifiable entre deux appels.
  ReviewDraft draft;

  /// Durée de chaque mise en mots.
  Duration delay;

  /// Vrai : la mise en mots ne se termine jamais d'elle-même, seulement par
  /// [cancel] (elle rend alors [WriterFailed]).
  bool hang;

  /// Si non nul, [write] lève cette erreur (le contrat l'interdit : sert à
  /// vérifier que l'appelant ne plante pas quand même).
  Object? throwError;

  /// Faits reçus, dans l'ordre.
  final List<ReviewFacts> received = [];

  int cancelCalls = 0;

  /// Mises en mots en cours, et le plus grand nombre observé en même temps.
  int running = 0;
  int maxConcurrent = 0;

  /// Mises en mots terminées (rendues), annulées ou non.
  int completed = 0;

  final List<Completer<void>> _pending = [];

  int get writeCalls => received.length;

  @override
  Future<ReviewDraft> write(ReviewFacts facts) async {
    received.add(facts);
    running++;
    if (running > maxConcurrent) maxConcurrent = running;
    try {
      if (throwError != null) throw throwError!;
      if (hang) {
        final pending = Completer<void>();
        _pending.add(pending);
        await pending.future;
        return const WriterFailed();
      }
      if (delay > Duration.zero) {
        final pending = Completer<void>();
        _pending.add(pending);
        final timer = Timer(delay, () {
          if (!pending.isCompleted) pending.complete();
        });
        await pending.future;
        timer.cancel();
        if (_cancelled.remove(pending)) return const WriterFailed();
      }
      return draft;
    } finally {
      running--;
      completed++;
    }
  }

  final Set<Completer<void>> _cancelled = {};

  @override
  Future<void> cancel() async {
    cancelCalls++;
    for (final pending in _pending) {
      if (!pending.isCompleted) {
        _cancelled.add(pending);
        pending.complete();
      }
    }
    _pending.clear();
  }
}

/// Sortie conforme au schéma `{"text": string}`.
String jsonText(String text) =>
    '{"text": "${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"}';

/// Texte de bilan valide, sans chiffre ni conseil (maquette).
const validReviewText =
    'Une semaine notée presque chaque jour, le plus souvent du côté de « Bien ». '
    'La fatigue et le travail reviennent souvent, le calme aussi.';
