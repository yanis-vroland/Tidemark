// Outils communs aux tests de la spec 004 (étiquetage automatique) : étiquettes,
// variantes des faux pour les cas limites, file factice pour les écrans, lecture des
// blocs de la spec. Aucun modèle d'IA, aucun réseau.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/model/model_state.dart';

import 'fake_entry_repository.dart';
import 'fake_model_downloader.dart';
import 'fake_mood_analyzer.dart';

/// Chemin de la spec, relatif à la racine du dépôt (dossier courant de `flutter test`).
const specPath = 'docs/specs/004-etiquetage-automatique.md';

String readSpec() => File(specPath).readAsStringSync();

Tag emotion(String label) => Tag(label, TagKind.emotion);
Tag theme(String label) => Tag(label, TagKind.theme);

/// Étiquettes de l'exemple de la spec (CA2, CA27).
final fatigueCalmeTravail = [
  emotion('fatigue'),
  emotion('calme'),
  theme('travail'),
];

/// Le résultat est `Tagged` avec exactement ces étiquettes, dans cet ordre.
void expectTagged(AnalysisResult result, List<Tag> expected) {
  expect(result, isA<Tagged>(), reason: 'sortie attendue conforme');
  expect((result as Tagged).tags, expected);
}

/// Attend que [condition] soit vraie, en laissant tourner la boucle d'événements.
Future<void> until(
  bool Function() condition, {
  Duration limit = const Duration(seconds: 3),
}) async {
  final stop = DateTime.now().add(limit);
  while (!condition()) {
    if (DateTime.now().isAfter(stop)) {
      throw TimeoutException('condition jamais remplie', limit);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Laisse passer [duration] de temps réel : sert à vérifier qu'il ne se passe rien.
Future<void> wait([Duration duration = const Duration(milliseconds: 150)]) =>
    Future<void>.delayed(duration);

// ---------------------------------------------------------------------------
// Faux
// ---------------------------------------------------------------------------

/// Analyseur qui journalise ses appels dans l'ordre, et dont `cancel()` ne rend la
/// main qu'après [cancelReturnDelay] (le moteur n'est « libre » qu'à ce moment-là).
class LoggingAnalyzer extends FakeMoodAnalyzer {
  LoggingAnalyzer({
    super.results,
    super.fallback,
    super.delays,
    this.cancelReturnDelay = Duration.zero,
  });

  final Duration cancelReturnDelay;
  final List<String> events = [];

  @override
  Future<bool> prepare() {
    events.add('prepare');
    return super.prepare();
  }

  @override
  Future<AnalysisResult> analyze(String text) async {
    events.add('analyze:$text');
    final result = await super.analyze(text);
    events.add('done:$text');
    return result;
  }

  @override
  Future<void> cancel() async {
    events.add('cancel:start');
    await super.cancel();
    await Future<void>.delayed(cancelReturnDelay);
    events.add('cancel:end');
  }

  @override
  Future<void> release() {
    events.add('release');
    return super.release();
  }
}

/// Analyseur dont le moteur finit sa génération malgré `cancel()` : il rend
/// [lateResult] après [duration], et `cancel()` n'attend que cette fin.
class LateAnalyzer extends FakeMoodAnalyzer {
  LateAnalyzer({required this.duration, required this.lateResult});

  final Duration duration;
  final AnalysisResult lateResult;
  Completer<void>? _inFlight;

  @override
  Future<AnalysisResult> analyze(String text) async {
    received.add(text);
    final inFlight = Completer<void>();
    _inFlight = inFlight;
    await Future<void>.delayed(duration);
    inFlight.complete();
    return lateResult;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    await _inFlight?.future;
  }
}

/// Dépôt dont `pendingEntriesWithText` et `watchEntries` rendent les entrées de la
/// plus ancienne à la plus récente (l'ordre naturel de la base) : la file doit
/// trier elle-même, de la plus récente à la plus ancienne.
class AscendingRepository extends FakeEntryRepository {
  @override
  Stream<List<Entry>> watchEntries() =>
      super.watchEntries().map((list) => list.reversed.toList());

  @override
  Future<List<Entry>> pendingEntriesWithText() async =>
      (await super.pendingEntriesWithText()).reversed.toList();
}

/// Dépôt dont la première lecture des entrées « en attente » (la vérification de
/// détresse au démarrage) attend [gate] ou échoue, selon [failFirstRead].
class FirstReadRepository extends FakeEntryRepository {
  FirstReadRepository({this.gated = false, this.failFirstRead = false});

  final bool gated;
  final bool failFirstRead;
  final Completer<void> gate = Completer<void>();
  int pendingReads = 0;

  @override
  Future<List<Entry>> pendingEntriesWithText() async {
    pendingReads++;
    if (pendingReads == 1) {
      if (gated) await gate.future;
      if (failFirstRead) throw StateError('lecture impossible');
    }
    return super.pendingEntriesWithText();
  }
}

/// Téléchargeur qui compte les observations de son état.
class WatchCountingDownloader extends FakeModelDownloader {
  WatchCountingDownloader([super.initial]);

  int watchCalls = 0;

  @override
  Stream<ModelState> watch() {
    watchCalls++;
    return super.watch();
  }
}

/// Téléchargeur dont la vérification de l'empreinte trouve un fichier altéré :
/// fichier effacé, modèle `absent` (spec 003, CA32).
class CorruptedModelDownloader extends FakeModelDownloader {
  CorruptedModelDownloader([super.initial]);

  @override
  Future<void> verifyAfterLoadFailure() async {
    verifyCalls++;
    emit(const ModelAbsent());
  }
}

/// File d'analyse réglée à la main, pour tester les écrans sans file réelle : ils
/// ne lisent que `currentEntryId` et `state`, et se reconstruisent à chaque
/// notification.
class StubAnalysisQueue extends AnalysisQueue {
  StubAnalysisQueue({int? current, AnalysisQueueState? state})
    : super(
        repository: FakeEntryRepository(),
        analyzer: FakeMoodAnalyzer(),
        downloader: FakeModelDownloader(),
      ) {
    _current = current;
    _state = state ?? AnalysisQueueState.idle;
  }

  int? _current;
  late AnalysisQueueState _state;

  @override
  int? get currentEntryId => _current;

  @override
  AnalysisQueueState get state => _state;

  void setCurrent(int? id) {
    _current = id;
    notifyListeners();
  }

  void setState(AnalysisQueueState state) {
    _state = state;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Blocs de la spec (CA1)
// ---------------------------------------------------------------------------

/// Premier bloc de code [lang] sous le titre qui commence par [heading], jusqu'au
/// titre suivant. Les lignes `#` d'un bloc de code ne sont pas des titres.
String fencedBlock(
  String markdown, {
  required String heading,
  required String lang,
}) {
  var inSection = false;
  var inFence = false;
  var collecting = false;
  final block = <String>[];
  for (final line in const LineSplitter().convert(markdown)) {
    if (line.startsWith('```')) {
      if (inFence) {
        inFence = false;
        if (collecting) return block.join('\n');
      } else {
        inFence = true;
        collecting = inSection && line.trim() == '```$lang';
      }
      continue;
    }
    if (inFence) {
      if (collecting) block.add(line);
      continue;
    }
    if (line.startsWith('#')) {
      if (line.startsWith(heading)) {
        inSection = true;
      } else if (inSection) {
        break;
      }
    }
  }
  throw FormatException(
    'aucun bloc « $lang » sous le titre « $heading » dans la spec',
  );
}

/// Lit le bloc de la liste fermée selon le format de la spec : une ligne
/// `# Émotions`, une étiquette par ligne, une ligne `# Thèmes`, une étiquette par
/// ligne ; ni ligne vide, ni commentaire, ni espace en début ou en fin de ligne.
/// Lève une [FormatException] dont le message dit ce qui ne va pas.
({List<String> emotions, List<String> themes}) parseVocabularyBlock(
  String block,
) {
  final lines = block.split('\n');
  final emotions = <String>[];
  final themes = <String>[];
  List<String>? current;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final where = 'ligne ${i + 1} du bloc';
    if (line.isEmpty) {
      throw FormatException('ligne vide interdite ($where)');
    }
    if (line != line.trimRight()) {
      throw FormatException('espace en fin de ligne interdit ($where)');
    }
    if (line != line.trimLeft()) {
      throw FormatException('espace en début de ligne interdit ($where)');
    }
    if (line == '# Émotions') {
      if (i != 0) {
        throw FormatException('« # Émotions » doit être la première ligne');
      }
      current = emotions;
    } else if (line == '# Thèmes') {
      if (current != emotions || emotions.isEmpty) {
        throw const FormatException(
          '« # Thèmes » doit suivre les émotions, qui ne sont pas vides',
        );
      }
      current = themes;
    } else if (line.startsWith('#')) {
      throw FormatException('commentaire interdit ($where) : « $line »');
    } else {
      if (current == null) {
        throw const FormatException(
          'la première ligne doit être « # Émotions »',
        );
      }
      current.add(line);
    }
  }
  if (themes.isEmpty) {
    throw const FormatException('section « # Thèmes » absente ou vide');
  }
  return (emotions: emotions, themes: themes);
}
