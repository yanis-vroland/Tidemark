import '../distress/distress_detector.dart';

/// Validateur du texte du bilan (glossaire : `ReviewTextValidator`, RM53) : règles
/// déterministes, code Dart pur, sans modèle.
class ReviewTextValidator {
  const ReviewTextValidator({this.detector = const DistressDetector()});

  final DistressDetector detector;

  /// Nombre maximal de caractères visibles du texte.
  static const maxLength = 300;

  /// Texte à afficher, sans espaces au début ni à la fin, ou `null` si la sortie
  /// brute [output] est rejetée.
  String? validate(String output) => throw UnimplementedError();
}
