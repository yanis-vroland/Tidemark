import 'dart:async';

import '../model/model_downloader.dart';
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

  /// État à afficher tout de suite pour [review], sans appeler le rédacteur :
  /// [NarrationWithheld] pour une semaine sensible (dont le texte gardé est
  /// effacé), le texte gardé pour les mêmes faits, [NarrationModelMissing] sans
  /// modèle prêt ; sinon [NarrationWriting] : [narrate] reste à appeler.
  Narration immediate(ComputedWeek review) => throw UnimplementedError();

  /// Met [review] en mots : mêmes vérifications que [immediate], puis rédacteur
  /// dans la limite de [timeout], validation, et mémoire du texte validé.
  Future<Narration> narrate(ComputedWeek review) => throw UnimplementedError();

  /// Abandonne la mise en mots en cours : rien n'en est gardé.
  Future<void> cancel() => throw UnimplementedError();
}
