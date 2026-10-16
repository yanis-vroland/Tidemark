// Mise en mots du bilan et vérification de l'empreinte (spec 006, CA37 ; spec 003,
// CA34 ; ADR-004). Rédacteur et téléchargeur factices : aucun modèle, aucun calcul
// d'empreinte réel. Le calcul « en cours » est simulé par `verifyBeforeLoadGate`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/review/review_narrator.dart';
import 'package:tidemark/review/review_writer.dart';
import 'package:tidemark/review/weekly_review.dart';

import '../support/analysis_harness.dart' show wait;
import '../support/fake_model_downloader.dart';
import '../support/fake_review_writer.dart';
import '../support/review_harness.dart';

/// Rédacteur qui note combien de vérifications avaient été demandées quand il a
/// été appelé : l'ordre « vérifier, puis rédiger ».
class OrderRecordingWriter extends FakeReviewWriter {
  OrderRecordingWriter(this.downloader);

  final FakeModelDownloader downloader;
  final List<int> verificationsAtWrite = [];

  @override
  Future<ReviewDraft> write(ReviewFacts facts) {
    verificationsAtWrite.add(downloader.verifyBeforeLoadCalls);
    return super.write(facts);
  }
}

class Setup {
  Setup({
    Duration timeout = const Duration(seconds: 5),
    FakeModelDownloader? downloader,
  }) : downloader = downloader ?? FakeModelDownloader(readyModel) {
    writer = OrderRecordingWriter(this.downloader);
    narrator = ReviewNarrator(
      writer: writer,
      downloader: this.downloader,
      timeout: timeout,
    );
    addTearDown(() {
      final gate = this.downloader.verifyBeforeLoadGate;
      if (gate != null && !gate.isCompleted) gate.complete();
    });
  }

  final FakeModelDownloader downloader;
  late final OrderRecordingWriter writer;
  late final ReviewNarrator narrator;

  Completer<void> holdVerification() {
    final gate = Completer<void>();
    downloader.verifyBeforeLoadGate = gate;
    return gate;
  }
}

void main() {
  test('spec 006 CA37 : verifyBeforeFirstLoad() est appelé avant le rédacteur '
      'et le texte est rendu', () async {
    final setup = Setup();

    final narration = await setup.narrator.narrate(computedWeek());

    expect(narration, isA<NarrationText>());
    expect(setup.writer.writeCalls, 1);
    expect(setup.downloader.verifyBeforeLoadCalls, greaterThanOrEqualTo(1));
    expect(
      setup.writer.verificationsAtWrite.single,
      greaterThanOrEqualTo(1),
      reason:
          'le rédacteur ne doit pas précéder la vérification de l\'empreinte',
    );
  });

  test('spec 006 CA37 : empreinte fausse (false) : le rédacteur n\'est pas '
      'appelé et la carte montre NarrationModelMissing', () async {
    final downloader = FakeModelDownloader(readyModel)
      ..fingerprintMatches = false;
    final setup = Setup(downloader: downloader);

    final narration = await setup.narrator.narrate(computedWeek());

    expect(narration, isA<NarrationModelMissing>());
    expect(setup.writer.writeCalls, 0);
    expect(downloader.verifyBeforeLoadCalls, 1);
    expect(downloader.current, isA<ModelAbsent>());
  });

  test(
    'spec 006 CA37 : une vérification qui rend false alors que le modèle '
    'reste prêt : pas de rédacteur, pas de texte, pas d\'exception',
    () async {
      final downloader = _AlwaysFalseDownloader();
      final setup = Setup(downloader: downloader);

      final narration = await setup.narrator.narrate(computedWeek());

      expect(setup.writer.writeCalls, 0);
      expect(narration, isNot(isA<NarrationText>()));
      expect(narration, isNot(isA<NarrationWriting>()));
    },
  );

  test('spec 006 CA37 : un calcul retenu plus long que le délai du narrateur '
      'ne compte pas dans ce délai : le texte arrive quand même', () async {
    final setup = Setup(timeout: const Duration(milliseconds: 100));
    final gate = setup.holdVerification();

    final pending = setup.narrator.narrate(computedWeek());
    await wait(const Duration(milliseconds: 400));
    expect(setup.writer.writeCalls, 0, reason: 'le calcul n\'est pas fini');
    gate.complete();
    final narration = await pending.timeout(const Duration(seconds: 3));

    expect(narration, isA<NarrationText>());
    expect(setup.writer.writeCalls, 1);
  });

  test(
    'spec 006 CA37 : le délai de 30 s court après le calcul : un rédacteur '
    'trop lent, une fois le calcul fini, vaut toujours « sans texte »',
    () async {
      final setup = Setup(timeout: const Duration(milliseconds: 100));
      setup.writer.hang = true;
      final gate = setup.holdVerification();

      final pending = setup.narrator.narrate(computedWeek());
      await wait(const Duration(milliseconds: 250));
      gate.complete();
      final narration = await pending.timeout(const Duration(seconds: 3));

      expect(narration, isA<NarrationWithheld>());
      expect(setup.writer.writeCalls, 1);
    },
  );

  test('spec 006 CA37 : cancel() pendant le calcul : le rédacteur n\'est '
      'jamais appelé', () async {
    final setup = Setup();
    final gate = setup.holdVerification();
    final pending = setup.narrator.narrate(computedWeek());
    await pumpEventQueue();
    expect(setup.downloader.verifyBeforeLoadCalls, 1);

    await setup.narrator.cancel();
    gate.complete();
    await pending.timeout(const Duration(seconds: 3));
    await wait(const Duration(milliseconds: 200));

    expect(setup.writer.writeCalls, 0);
  });

  test('spec 006 CA37 : forget() pendant le calcul : le rédacteur n\'est '
      'jamais appelé', () async {
    final setup = Setup();
    final gate = setup.holdVerification();
    final pending = setup.narrator.narrate(computedWeek());
    await pumpEventQueue();
    expect(setup.downloader.verifyBeforeLoadCalls, 1);

    await setup.narrator.forget();
    gate.complete();
    await pending.timeout(const Duration(seconds: 3));
    await wait(const Duration(milliseconds: 200));

    expect(setup.writer.writeCalls, 0);
  });

  test(
    'spec 006 CA37 : après un cancel() pendant le calcul, aucun texte n\'est '
    'gardé ; une mise en mots ultérieure appelle le rédacteur',
    () async {
      final setup = Setup();
      final gate = setup.holdVerification();
      final pending = setup.narrator.narrate(computedWeek());
      await pumpEventQueue();
      await setup.narrator.cancel();
      gate.complete();
      await pending.timeout(const Duration(seconds: 3));

      final again = await setup.narrator.narrate(computedWeek());

      expect(again, isA<NarrationText>());
      expect(setup.writer.writeCalls, 1);
    },
  );
}

/// Vérification qui rend `false` sans toucher à l'état du modèle (prêt).
class _AlwaysFalseDownloader extends FakeModelDownloader {
  _AlwaysFalseDownloader() : super(readyModel);

  @override
  Future<bool> verifyBeforeFirstLoad() async {
    verifyBeforeLoadCalls++;
    return false;
  }
}
