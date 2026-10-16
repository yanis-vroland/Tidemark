// Niveau des journaux de `llamadart` (spec 004, CA38 ; spec 006, décision 14 ;
// ADR-004, décision 4) : fixé à `none` avant chaque chargement, Dart et natif.
// Le réglage est pur Dart : aucun moteur n'est créé, aucun modèle chargé.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart' show LlamaLogLevel, LlamaLogging;
import 'package:tidemark/analysis/llama_mood_analyzer.dart';
import 'package:tidemark/review/llama_review_writer.dart';
import 'package:tidemark/review/review_writer.dart';

import '../support/review_harness.dart' show defaultFacts;

/// Moteur factice : jamais appelé, il n'existe que pour que le chargement réussisse.
class _IdleEngine implements LocalEngine {
  @override
  Future<String> generate(String text) async => '';

  @override
  void cancelGeneration() {}

  @override
  Future<void> dispose() async {}
}

typedef _Levels = ({LlamaLogLevel dart, LlamaLogLevel native});

_Levels _currentLevels() =>
    (dart: LlamaLogging.level, native: LlamaLogging.nativeLevel);

Future<void> _setInfo() => LlamaLogging.configure(
  level: LlamaLogLevel.info,
  nativeLevel: LlamaLogLevel.info,
);

void main() {
  setUp(() async {
    await _setInfo();
    // Précondition : les niveaux sont bien à `info` avant l'appel testé.
    expect(LlamaLogging.level, LlamaLogLevel.info);
    expect(LlamaLogging.nativeLevel, LlamaLogLevel.info);
  });
  tearDown(
    () => LlamaLogging.configure(
      level: LlamaLogLevel.none,
      nativeLevel: LlamaLogLevel.none,
    ),
  );

  group('LlamaMoodAnalyzer (spec 004)', () {
    test('spec 004 CA38 : au moment du chargement par la couture LocalEngine, '
        'les niveaux Dart et natif valent none', () async {
      final seen = <_Levels>[];
      final analyzer = LlamaMoodAnalyzer(
        modelFile: File('inexistant.gguf'),
        gpuLayers: 0,
        loader: (file, layers) async {
          seen.add(_currentLevels());
          return _IdleEngine();
        },
      );

      expect(await analyzer.prepare(), isTrue);

      expect(seen, hasLength(1), reason: 'le chargeur doit être appelé');
      expect(seen.single.dart, LlamaLogLevel.none);
      expect(seen.single.native, LlamaLogLevel.none);
    });

    test('spec 004 CA38 : après le chargement, les niveaux valent toujours '
        'none', () async {
      final analyzer = LlamaMoodAnalyzer(
        modelFile: File('inexistant.gguf'),
        gpuLayers: 0,
        loader: (file, layers) async => _IdleEngine(),
      );

      await analyzer.prepare();

      expect(LlamaLogging.level, LlamaLogLevel.none);
      expect(LlamaLogging.nativeLevel, LlamaLogLevel.none);
    });

    test('spec 004 CA38 : un chargement qui échoue laisse aussi les niveaux à '
        'none, avant comme après', () async {
      final seen = <_Levels>[];
      final analyzer = LlamaMoodAnalyzer(
        modelFile: File('inexistant.gguf'),
        gpuLayers: 0,
        loader: (file, layers) async {
          seen.add(_currentLevels());
          throw StateError('chargement impossible');
        },
      );

      expect(await analyzer.prepare(), isFalse);

      expect(seen.single.dart, LlamaLogLevel.none);
      expect(seen.single.native, LlamaLogLevel.none);
      expect(LlamaLogging.level, LlamaLogLevel.none);
      expect(LlamaLogging.nativeLevel, LlamaLogLevel.none);
    });

    test(
      'spec 004 CA38 : à chaque chargement, pas seulement au premier : des '
      'niveaux remis à info entre deux chargements sont ramenés à none',
      () async {
        final seen = <_Levels>[];
        final analyzer = LlamaMoodAnalyzer(
          modelFile: File('inexistant.gguf'),
          gpuLayers: 0,
          loader: (file, layers) async {
            seen.add(_currentLevels());
            return _IdleEngine();
          },
        );
        await analyzer.prepare();
        await analyzer.release();
        await _setInfo();

        await analyzer.prepare();

        expect(seen, hasLength(2));
        expect(seen.last.dart, LlamaLogLevel.none);
        expect(seen.last.native, LlamaLogLevel.none);
      },
    );
  });

  group('LlamaReviewWriter (spec 006, décision 14)', () {
    test('spec 004 CA38 / spec 006 décision 14 : write() sur un fichier absent '
        'rend ModelMissing, sans moteur, et les niveaux valent none après', () async {
      final missing = File(
        '${Directory.systemTemp.path}/tidemark_absent_${DateTime.now().microsecondsSinceEpoch}.gguf',
      );
      expect(missing.existsSync(), isFalse);
      final writer = LlamaReviewWriter(modelFile: missing, gpuLayers: 0);

      final draft = await writer.write(defaultFacts);

      expect(draft, isA<ModelMissing>());
      expect(LlamaLogging.level, LlamaLogLevel.none);
      expect(LlamaLogging.nativeLevel, LlamaLogLevel.none);
    });
  });
}
