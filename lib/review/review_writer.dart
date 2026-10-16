/// Rédacteur du bilan, derrière une interface : l'app ne connaît jamais le moteur
/// (ADR-001). Les tests et la CI utilisent `FakeReviewWriter` (test/support/),
/// jamais un vrai modèle.
library;

import 'weekly_review.dart';

/// Ce que rend le rédacteur.
sealed class ReviewDraft {
  const ReviewDraft();
}

/// Sortie brute du modèle, à valider par `ReviewTextValidator` (RM53). Jamais
/// affichée, enregistrée ni journalisée telle quelle.
final class RawReview extends ReviewDraft {
  const RawReview(this.output);

  final String output;
}

/// Modèle absent (supprimé entre-temps) : message de CA27.
final class ModelMissing extends ReviewDraft {
  const ModelMissing();
}

/// Erreur du modèle : bilan sans texte, message de CA22.
final class WriterFailed extends ReviewDraft {
  const WriterFailed();
}

/// Rédacteur (glossaire : `ReviewWriter`, spec 006). Une génération à la fois ; le
/// délai de 30 s et la validation sont tenus par l'appelant.
abstract interface class ReviewWriter {
  /// Met en mots [facts], et rien d'autre (RM51). Ne lève jamais d'exception.
  Future<ReviewDraft> write(ReviewFacts facts);

  /// Abandonne la mise en mots en cours (délai dépassé, écran quitté) ; ne rend
  /// la main qu'une fois le moteur libre. Sans effet si rien n'est en cours.
  Future<void> cancel();
}

/// Rédacteur sans modèle : rend toujours [ModelMissing]. Sert quand l'app n'a pas
/// de rédacteur réel (tests des autres specs).
class NoReviewWriter implements ReviewWriter {
  const NoReviewWriter();

  @override
  Future<ReviewDraft> write(ReviewFacts facts) async => const ModelMissing();

  @override
  Future<void> cancel() async {}
}

/// Consigne fixe passée au modèle (spec 006, « Ce que reçoit le modèle », RM22).
const reviewInstruction =
    'Tu rédiges le bilan d\'une semaine de journal d\'humeur, en français, pour '
    'la personne qui tient ce journal. Écris une ou deux phrases courtes, en la '
    'tutoyant, sur un ton descriptif et calme. Décris seulement les faits donnés, '
    'rien d\'autre. N\'écris aucun chiffre et aucun nombre, même en lettres. Ne '
    'donne aucun conseil, ne porte aucun jugement, n\'emploie aucun vocabulaire '
    'médical. Réponds seulement par l\'objet JSON demandé.';

/// Schéma JSON de la sortie : `{"text": string}` (ADR-001).
const reviewOutputSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'text': {'type': 'string'},
  },
  'required': ['text'],
  'additionalProperties': false,
};

/// Nombre maximal de jetons générés (spec 006).
const reviewMaxTokens = 160;

/// Température de génération (ADR-001).
const reviewTemperature = 0.2;
