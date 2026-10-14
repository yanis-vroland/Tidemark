import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';

void main() {
  test(
    'rend le résultat prévu pour un texte et note ce qu\'il a reçu',
    () async {
      const tags = [
        Tag('fatigue', TagKind.emotion),
        Tag('travail', TagKind.theme),
      ];
      final analyzer = FakeMoodAnalyzer(
        results: {'Longue journée.': const Tagged(tags)},
      );

      final result = await analyzer.analyze('Longue journée.');

      expect(result, isA<Tagged>());
      expect((result as Tagged).tags, tags);
      expect(analyzer.received, ['Longue journée.']);
    },
  );

  test('rend « sans étiquette » par défaut (RM9)', () async {
    final analyzer = FakeMoodAnalyzer();

    expect(await analyzer.analyze('Texte inconnu'), isA<Untagged>());
  });
}
