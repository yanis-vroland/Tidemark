import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark_spike/labeling.dart';

void main() {
  const vocabulary = Vocabulary(
    emotions: ['joie', 'calme', 'fatigue'],
    themes: ['travail', 'nature'],
  );

  test('accepte un JSON conforme, même entouré de texte', () {
    final labels = parseLabels(
      'Voici : {"emotions": ["fatigue", "calme"], "themes": ["travail"]} fin',
      vocabulary,
    );
    expect(labels, isNotNull);
    expect(labels!.emotions, ['fatigue', 'calme']);
    expect(labels.themes, ['travail']);
  });

  test('refuse un JSON invalide', () {
    expect(parseLabels('{"emotions": ["joie"', vocabulary), isNull);
  });

  test('refuse une étiquette hors vocabulaire', () {
    expect(
      parseLabels('{"emotions": ["mélancolie"], "themes": ["travail"]}', vocabulary),
      isNull,
    );
  });

  test('refuse une liste vide ou trop longue', () {
    expect(parseLabels('{"emotions": [], "themes": ["travail"]}', vocabulary), isNull);
    expect(
      parseLabels('{"emotions": ["joie"], "themes": ["travail", "nature", "travail"]}', vocabulary),
      isNull,
    );
  });

  test('refuse une sortie sans objet JSON', () {
    expect(parseLabels('Je ne peux pas répondre.', vocabulary), isNull);
  });

  test('calcule le rappel sur les étiquettes attendues', () {
    const entry = SpikeEntry(
      id: 1,
      mood: 4,
      text: '',
      expectedEmotions: ['fatigue', 'calme'],
      expectedThemes: ['travail', 'nature'],
    );
    expect(recall(const Labels(['fatigue'], ['travail']), entry), 0.5);
  });
}
