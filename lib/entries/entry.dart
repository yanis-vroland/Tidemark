/// Entrée du journal (glossaire : `Entry`) et son statut d'analyse.
library;

import '../analysis/mood_analyzer.dart';

/// Où en est l'analyse d'une entrée (glossaire : `AnalysisStatus`).
enum AnalysisStatus {
  /// En attente : l'entrée a un texte, l'analyse n'a pas encore eu lieu.
  pending,

  /// Étiquetée.
  tagged,

  /// Sans étiquette : sortie du modèle non conforme ou erreur (RM9).
  untagged,

  /// Non analysée : sans texte (RM24) ou détresse détectée (RM17).
  skipped,
}

/// Libellés fixes des humeurs (RM3).
const moodLabels = ['Très bas', 'Bas', 'Neutre', 'Bien', 'Très bien'];

/// Libellé de l'humeur [mood], de 1 à 5.
String moodLabel(int mood) => moodLabels[mood - 1];

/// Longueur maximale du texte d'une entrée (RM27), en caractères visibles : un
/// drapeau ou un émoji composé compte pour un.
const maxTextLength = 2000;

class Entry {
  const Entry({
    required this.id,
    required this.mood,
    required this.text,
    required this.createdAt,
    required this.utcOffset,
    required this.analysisStatus,
    this.tags = const [],
  });

  final int id;

  /// Humeur, de 1 à 5 (RM3).
  final int mood;

  /// Texte facultatif (RM13) : null si la personne n'a rien écrit.
  final String? text;

  /// Date et heure de la saisie, en UTC (RM16).
  final DateTime createdAt;

  /// Décalage horaire local au moment de la saisie : l'entrée reste rangée dans le
  /// jour local où elle a été saisie, même après un changement de fuseau.
  final Duration utcOffset;

  final AnalysisStatus analysisStatus;

  /// Étiquettes de l'entrée, émotions puis thèmes, dans l'ordre enregistré ; vide
  /// si elle n'est pas « étiquetée » (spec 004).
  final List<Tag> tags;

  /// Date et heure locales de la saisie (heure murale, marquée UTC par convention).
  DateTime get localCreatedAt => createdAt.toUtc().add(utcOffset);
}
