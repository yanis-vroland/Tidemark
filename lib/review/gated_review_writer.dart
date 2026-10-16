import 'dart:async';

import '../model/model_gate.dart';
import 'review_writer.dart';
import 'weekly_review.dart';

/// [ReviewWriter] qui attend l'accès au modèle ([ModelGate]) avant chaque mise en
/// mots, et ne le rend qu'une fois le rédacteur revenu : jamais deux générations à
/// la fois (spec 006, « Modèle occupé par l'étiquetage », ADR-005).
class GatedReviewWriter implements ReviewWriter {
  GatedReviewWriter(this.inner, this.gate);

  final ReviewWriter inner;
  final ModelGate gate;

  /// Demandes en attente de l'accès, abandonnées par [cancel].
  final Set<Completer<void>> _waiting = {};

  /// Mises en mots en cours, après obtention de l'accès.
  int _running = 0;

  /// Rend [WriterFailed] si [cancel] arrive avant l'accès.
  @override
  Future<ReviewDraft> write(ReviewFacts facts) async {
    final abandon = Completer<void>();
    _waiting.add(abandon);
    final void Function()? release;
    try {
      release = await gate.acquire(abandon: abandon.future);
    } finally {
      _waiting.remove(abandon);
    }
    if (release == null) return const WriterFailed();
    // Abandon arrivé après la transmission de l'accès, avant la reprise : rien
    // n'est chargé, l'accès est rendu aussitôt (revue de sécurité).
    if (abandon.isCompleted) {
      release();
      return const WriterFailed();
    }
    _running++;
    try {
      return await inner.write(facts);
    } catch (_) {
      return const WriterFailed();
    } finally {
      _running--;
      // Rendu seulement une fois le rédacteur revenu : le moteur est libre.
      release();
    }
  }

  @override
  Future<void> cancel() async {
    for (final abandon in [..._waiting]) {
      if (!abandon.isCompleted) abandon.complete();
    }
    _waiting.clear();
    if (_running > 0) await inner.cancel();
  }
}
