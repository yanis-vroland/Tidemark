import 'dart:convert';

/// Vocabulaire provisoire du spike (voir assets/entries.json).
class Vocabulary {
  const Vocabulary({required this.emotions, required this.themes});

  factory Vocabulary.fromJson(Map<String, dynamic> json) => Vocabulary(
    emotions: List<String>.from(json['emotions'] as List),
    themes: List<String>.from(json['themes'] as List),
  );

  final List<String> emotions;
  final List<String> themes;
}

class SpikeEntry {
  const SpikeEntry({
    required this.id,
    required this.mood,
    required this.text,
    required this.expectedEmotions,
    required this.expectedThemes,
  });

  factory SpikeEntry.fromJson(Map<String, dynamic> json) {
    final expected = json['expected'] as Map<String, dynamic>;
    return SpikeEntry(
      id: json['id'] as int,
      mood: json['mood'] as int,
      text: json['text'] as String,
      expectedEmotions: List<String>.from(expected['emotions'] as List),
      expectedThemes: List<String>.from(expected['themes'] as List),
    );
  }

  final int id;
  final int mood;
  final String text;
  final List<String> expectedEmotions;
  final List<String> expectedThemes;
}

/// Étiquettes d'une entrée, après validation.
class Labels {
  const Labels(this.emotions, this.themes);

  final List<String> emotions;
  final List<String> themes;
}

/// Prompt commun aux deux moteurs : seul le moteur change d'une mesure à l'autre.
String buildPrompt(Vocabulary vocabulary, String text) =>
    '''
Tu étiquettes une entrée de journal d'humeur écrite en français.
Choisis de 1 à 3 émotions dans cette liste : ${vocabulary.emotions.join(', ')}.
Choisis de 1 à 2 thèmes dans cette liste : ${vocabulary.themes.join(', ')}.
N'utilise aucun autre mot. Réponds uniquement avec un objet JSON, sans texte autour, de la forme :
{"emotions": ["..."], "themes": ["..."]}

Entrée : """$text"""
''';

/// Valide la sortie brute du modèle (RM9 : sortie non conforme → aucune étiquette).
/// Retourne null si la sortie ne respecte pas le schéma ou le vocabulaire.
Labels? parseLabels(String raw, Vocabulary vocabulary) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw.substring(start, end + 1));
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final emotions = decoded['emotions'];
  final themes = decoded['themes'];
  if (emotions is! List || themes is! List) return null;
  if (emotions.isEmpty || emotions.length > 3) return null;
  if (themes.isEmpty || themes.length > 2) return null;
  if (!emotions.every((e) => e is String && vocabulary.emotions.contains(e))) {
    return null;
  }
  if (!themes.every((t) => t is String && vocabulary.themes.contains(t))) {
    return null;
  }
  return Labels(List<String>.from(emotions), List<String>.from(themes));
}

/// Part des étiquettes attendues retrouvées (rappel), entre 0 et 1.
double recall(Labels labels, SpikeEntry entry) {
  final expected = {...entry.expectedEmotions, ...entry.expectedThemes};
  final found = {...labels.emotions, ...labels.themes};
  return expected.where(found.contains).length / expected.length;
}
