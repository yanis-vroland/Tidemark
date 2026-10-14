/// Analyse d'une entrée par le modèle local, derrière une interface : l'app ne connaît
/// jamais le moteur (ADR-001). Les tests et la CI utilisent `FakeMoodAnalyzer`
/// (test/support/), jamais un vrai modèle.
library;

/// Type d'étiquette (glossaire : `TagKind`).
enum TagKind { emotion, theme }

/// Émotion ou thème associé à une entrée, pris dans une liste fermée (RM19).
class Tag {
  const Tag(this.label, this.kind);

  final String label;
  final TagKind kind;

  @override
  bool operator ==(Object other) =>
      other is Tag && other.label == label && other.kind == kind;

  @override
  int get hashCode => Object.hash(label, kind);

  @override
  String toString() => 'Tag($label, ${kind.name})';
}

/// Résultat d'une analyse.
sealed class AnalysisResult {
  const AnalysisResult();
}

/// Sortie conforme : les étiquettes de l'entrée.
final class Tagged extends AnalysisResult {
  const Tagged(this.tags);

  final List<Tag> tags;
}

/// Sortie non conforme ou erreur du modèle : l'entrée reste sans étiquette (RM9).
final class Untagged extends AnalysisResult {
  const Untagged();
}

abstract interface class MoodAnalyzer {
  /// Analyse le texte d'une entrée. Ne lève jamais d'exception : toute erreur du
  /// modèle devient [Untagged].
  Future<AnalysisResult> analyze(String text);
}
