import 'mood_analyzer.dart';

/// Validation de la sortie du modèle (spec 004, « Validation de la sortie », RM9) :
/// code Dart pur, qui ne lève jamais d'exception.
abstract final class TagOutputParser {
  /// [Tagged] si [raw] est conforme, [Untagged] sinon.
  static AnalysisResult parse(String raw) => throw UnimplementedError();
}
