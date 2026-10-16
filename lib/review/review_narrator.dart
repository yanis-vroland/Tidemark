import 'dart:async';

import '../model/model_downloader.dart';
import '../model/model_state.dart';
import 'local_week.dart';
import 'review_text_validator.dart';
import 'review_writer.dart';
import 'weekly_review.dart';

/// État de la carte du texte du bilan.
sealed class Narration {
  const Narration();
}

/// Mise en mots en cours (CA18).
final class NarrationWriting extends Narration {
  const NarrationWriting();
}

/// Texte validé, à afficher (CA19).
final class NarrationText extends Narration {
  const NarrationText(this.text);

  final String text;
}

/// Pas de texte : semaine sensible, sortie rejetée, erreur ou délai dépassé
/// (CA20, CA22, CA26).
final class NarrationWithheld extends Narration {
  const NarrationWithheld();
}

/// Pas de texte : modèle absent (CA27).
final class NarrationModelMissing extends Narration {
  const NarrationModelMissing();
}

/// Texte validé pour une semaine, et les faits dont il est tiré.
typedef _Kept = ({ReviewFacts facts, String text});

/// Mise en mots du bilan (RM51 à RM54) : sensibilité, mémoire, état du modèle,
/// rédacteur avec son délai, validation. Garde les textes validés en mémoire tant
/// que l'app est ouverte, jamais dans la base.
class ReviewNarrator {
  ReviewNarrator({
    required this.writer,
    required this.downloader,
    this.validator = const ReviewTextValidator(),
    this.timeout = const Duration(seconds: 30),
  });

  final ReviewWriter writer;
  final ModelDownloader downloader;
  final ReviewTextValidator validator;

  /// Délai de réponse du rédacteur (CA26).
  final Duration timeout;

  /// Textes validés, par semaine (RM54) : en mémoire seulement.
  final Map<LocalWeek, _Kept> _kept = {};

  /// Incrémenté par [cancel] : une mise en mots lancée avant n'est plus gardée.
  int _generation = 0;

  /// État à afficher tout de suite pour [review], sans appeler le rédacteur :
  /// [NarrationWithheld] pour une semaine sensible (dont le texte gardé est
  /// effacé), le texte gardé pour les mêmes faits, [NarrationModelMissing] sans
  /// modèle prêt ; sinon [NarrationWriting] : [narrate] reste à appeler.
  Narration immediate(ComputedWeek review) {
    // La sensibilité d'abord, avant toute lecture de la mémoire (CA34) : une
    // entrée à « Très bas » peut laisser les faits identiques.
    if (review.isSensitive) {
      _kept.remove(review.week);
      return const NarrationWithheld();
    }
    final kept = _kept[review.week];
    if (kept != null && kept.facts == review.facts) {
      return NarrationText(kept.text);
    }
    if (downloader.current is! ModelReady) return const NarrationModelMissing();
    return const NarrationWriting();
  }

  /// Met [review] en mots : mêmes vérifications que [immediate], puis rédacteur
  /// dans la limite de [timeout], validation, et mémoire du texte validé.
  Future<Narration> narrate(ComputedWeek review) async {
    final now = immediate(review);
    if (now is! NarrationWriting) return now;
    final generation = _generation;
    final draft = await _write(review.facts);
    switch (draft) {
      case ModelMissing():
        return const NarrationModelMissing();
      case WriterFailed():
        return const NarrationWithheld();
      case RawReview(:final output):
        // La sortie brute n'est ni gardée, ni montrée, ni journalisée (RM53).
        final text = validator.validate(output);
        if (text == null) return const NarrationWithheld();
        if (generation == _generation) {
          _kept[review.week] = (facts: review.facts, text: text);
        }
        return NarrationText(text);
    }
  }

  /// Rédacteur dans la limite de [timeout] ; au-delà, la génération est abandonnée
  /// et le bilan reste sans texte (CA26).
  Future<ReviewDraft> _write(ReviewFacts facts) async {
    final Future<ReviewDraft> writing;
    try {
      writing = writer.write(facts);
    } catch (_) {
      return const WriterFailed();
    }
    try {
      return await writing.timeout(timeout);
    } on TimeoutException {
      await _cancelWriter();
      // Le rédacteur rend la main après l'abandon ; son résultat est ignoré.
      unawaited(writing.then((_) {}, onError: (Object _) {}));
      return const WriterFailed();
    } catch (_) {
      return const WriterFailed();
    }
  }

  /// Abandonne la mise en mots en cours et oublie tous les textes gardés en
  /// mémoire (suppression totale, spec 005).
  Future<void> forget() async {}

  /// Abandonne la mise en mots en cours : rien n'en est gardé.
  Future<void> cancel() async {
    _generation++;
    await _cancelWriter();
  }

  Future<void> _cancelWriter() async {
    try {
      await writer.cancel();
    } catch (_) {}
  }
}
