// Annulation de `LlamaMoodAnalyzer` (spec 004, CA35) sur un moteur factice : aucun
// vrai modèle, jamais `loadLlamadartEngine`.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/llama_mood_analyzer.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';

import '../support/analysis_harness.dart';

const conformingOutput =
    '{"emotions": ["fatigue", "calme"], "themes": ["travail"]}';

const grace = Duration(milliseconds: 200);

/// Moteur factice : la génération se règle par [onCancel] (ce que fait le moteur
/// quand on lui demande de s'arrêter) et par [generation].
class FakeEngine implements LocalEngine {
  FakeEngine({this.onCancel, this.error});

  /// Appelé par `cancelGeneration` ; `null` : le moteur ignore la demande.
  final void Function(FakeEngine engine)? onCancel;

  /// Si non nul, `generate` lève cette erreur.
  final Object? error;

  final List<String> events = [];
  final Completer<String> generation = Completer<String>();
  final Completer<void> started = Completer<void>();
  int disposeCalls = 0;
  int cancelGenerationCalls = 0;

  @override
  Future<String> generate(String text) async {
    events.add('generate:start');
    if (!started.isCompleted) started.complete();
    if (error != null) throw error!;
    final output = await generation.future;
    events.add('generate:end');
    return output;
  }

  @override
  void cancelGeneration() {
    cancelGenerationCalls++;
    events.add('cancelGeneration');
    onCancel?.call(this);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    events.add('dispose');
  }
}

class Setup {
  Setup(this.engine) {
    analyzer = LlamaMoodAnalyzer(
      modelFile: File('unused.gguf'),
      gpuLayers: 0,
      cancelGrace: grace,
      loader: (file, layers) async {
        loaderCalls++;
        return engine;
      },
    );
  }

  final FakeEngine engine;
  late final LlamaMoodAnalyzer analyzer;
  int loaderCalls = 0;
}

void main() {
  test('CA35 : cancel() demande l\'arrêt au moteur et ne rend la main qu\'à la '
      'fin de la génération', () async {
    final engine = FakeEngine(
      onCancel: (e) => Timer(
        const Duration(milliseconds: 100),
        () => e.generation.complete(''),
      ),
    );
    final setup = Setup(engine);
    expect(await setup.analyzer.prepare(), isTrue);
    final analysis = setup.analyzer.analyze('texte');
    await engine.started.future.timeout(const Duration(seconds: 1));

    await setup.analyzer.cancel().timeout(const Duration(seconds: 2));
    engine.events.add('cancel:returned');
    await analysis.timeout(const Duration(seconds: 1));

    expect(engine.cancelGenerationCalls, 1);
    expect(engine.events, [
      'generate:start',
      'cancelGeneration',
      'generate:end',
      'cancel:returned',
    ]);
    expect(engine.disposeCalls, 0);
  });

  test('CA35 : une génération qui ignore l\'arrêt : cancel() rend la main '
      'après le délai borné, le moteur est libéré, l\'analyse rend Untagged '
      'et prepare() recharge le modèle', () async {
    final engine = FakeEngine();
    final setup = Setup(engine);
    expect(await setup.analyzer.prepare(), isTrue);
    final analysis = setup.analyzer.analyze('texte');
    await engine.started.future.timeout(const Duration(seconds: 1));

    final watch = Stopwatch()..start();
    await setup.analyzer.cancel().timeout(const Duration(seconds: 3));
    watch.stop();

    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 150)),
      reason: 'cancel() doit attendre la fin de la génération, jusqu\'au délai',
    );
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
    expect(engine.disposeCalls, 1);
    expect(await analysis.timeout(const Duration(seconds: 1)), isA<Untagged>());

    expect(await setup.analyzer.prepare(), isTrue);
    expect(setup.loaderCalls, 2);
  });

  test('CA35 : cancel() sans génération en cours rend la main tout de suite, '
      'sans libérer le moteur', () async {
    final engine = FakeEngine();
    final setup = Setup(engine);
    expect(await setup.analyzer.prepare(), isTrue);

    final watch = Stopwatch()..start();
    await setup.analyzer.cancel().timeout(const Duration(seconds: 2));
    watch.stop();

    expect(watch.elapsed, lessThan(const Duration(milliseconds: 100)));
    expect(engine.disposeCalls, 0);
  });

  test('CA35 : cancel() avant tout chargement du modèle rend la main tout de '
      'suite', () async {
    final setup = Setup(FakeEngine());

    final watch = Stopwatch()..start();
    await setup.analyzer.cancel().timeout(const Duration(seconds: 2));
    watch.stop();

    expect(watch.elapsed, lessThan(const Duration(milliseconds: 100)));
    expect(setup.loaderCalls, 0);
  });

  test('CA35 : analyze() rend Tagged pour une sortie conforme', () async {
    final engine = FakeEngine();
    engine.generation.complete(conformingOutput);
    final setup = Setup(engine);
    expect(await setup.analyzer.prepare(), isTrue);

    final result = await setup.analyzer.analyze('texte');

    expectTagged(result, fatigueCalmeTravail);
  });

  test('CA35 : analyze() rend Untagged si le moteur lève', () async {
    final setup = Setup(FakeEngine(error: StateError('GPU refusé')));
    expect(await setup.analyzer.prepare(), isTrue);

    expect(await setup.analyzer.analyze('texte'), isA<Untagged>());
  });
}
