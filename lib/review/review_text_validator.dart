import 'dart:convert';

import 'package:characters/characters.dart';

import '../distress/distress_detector.dart';
import 'review_terms.dart';

/// Tout caractère de la catégorie Unicode « nombre » (chiffres de toute écriture,
/// exposants, fractions), et les signes pour cent et pour mille (règle 3).
final _numeric = RegExp(r'[\p{N}%‰]', unicode: true);

/// Validateur du texte du bilan (glossaire : `ReviewTextValidator`, RM53) : règles
/// déterministes, code Dart pur, sans modèle.
class ReviewTextValidator {
  const ReviewTextValidator({this.detector = const DistressDetector()});

  final DistressDetector detector;

  /// Nombre maximal de caractères visibles du texte.
  static const maxLength = 300;

  /// Texte à afficher, sans espaces au début ni à la fin, ou `null` si la sortie
  /// brute [output] est rejetée.
  String? validate(String output) {
    // Règle 1 : objet JSON `{"text": string}`, rien d'autre, texte non vide.
    final Object? decoded;
    try {
      decoded = jsonDecode(output);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    if (decoded.length != 1) return null;
    final raw = decoded['text'];
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    // Règle 2 : 300 caractères visibles au plus (un émoji composé compte pour un).
    if (text.characters.length > maxLength) return null;
    // Règle 3 : aucun caractère numérique, ni « % » ni « ‰ ».
    if (_numeric.hasMatch(text)) return null;
    // Règle 4 : aucun mot de nombre ni expression interdite, en mots entiers.
    final padded = ' ${DistressDetector.normalize(text)} ';
    bool found(String e) => padded.contains(' $e ');
    if (numberWords.any(found) || forbiddenExpressions.any(found)) return null;
    // Règle 5 : aucune détresse détectée.
    if (detector.detectInText(text)) return null;
    return text;
  }
}
