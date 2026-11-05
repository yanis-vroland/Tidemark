import 'dart:async';

import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/entry_repository.dart';
import 'package:tidemark/entries/topic.dart';

/// Dépôt factice en mémoire, sans base. [beforeAdd] permet de simuler un enregistrement
/// lent (attendre un `Completer`) ou en échec (lever une exception).
class FakeEntryRepository implements EntryRepository {
  FakeEntryRepository({
    this.beforeAdd,
    this.beforeDelete,
    this.watchError,
    DateTime Function()? clock,
  }) : clock = clock ?? (() => DateTime(2026, 10, 14, 21, 40));

  /// Instant de saisie donné aux entrées ajoutées (heure locale : 21:40 par défaut).
  DateTime Function() clock;

  /// Si non nul, [markSkipped] lève cette erreur (vérification au démarrage).
  Object? markSkippedError;

  /// Si non nul, [latestEntries] lève cette erreur (série illisible).
  Object? latestEntriesError;

  /// Appelé au début de chaque [addEntry] ; s'il lève, l'entrée n'est pas enregistrée.
  Future<void> Function()? beforeAdd;

  /// Appelé au début de chaque [deleteEntry] ; s'il lève, rien n'est supprimé.
  Future<void> Function()? beforeDelete;

  /// Si non nul, [watchEntries] émet cette erreur au lieu des entrées.
  Object? watchError;

  /// Flux en attente de premier résultat, pour montrer l'état de chargement.
  bool neverEmit = false;

  /// Appels à [addEntry], dans l'ordre, y compris ceux qui ont échoué.
  final List<
    ({int mood, String? text, AnalysisStatus status, List<Topic> topics})
  >
  addCalls = [];

  final List<Entry> _entries = [];
  final _changes = StreamController<List<Entry>>.broadcast();

  /// Entrées effectivement enregistrées, de la plus récente à la plus ancienne.
  List<Entry> get entries => List.unmodifiable(_entries);

  @override
  Stream<List<Entry>> watchEntries() async* {
    if (neverEmit) {
      await Completer<void>().future;
    }
    if (watchError != null) throw watchError!;
    yield entries;
    yield* _changes.stream;
  }

  /// Comme le vrai dépôt : l'entrée [id] ou `null`, réémise seulement quand elle
  /// change.
  @override
  Stream<Entry?> watchEntry(int id) => watchEntries()
      .map((entries) => entries.where((e) => e.id == id).firstOrNull)
      .distinct(sameEntry);

  @override
  Future<Entry> addEntry({
    required int mood,
    String? text,
    AnalysisStatus status = AnalysisStatus.pending,
    List<Topic> topics = const [],
  }) async {
    addCalls.add((mood: mood, text: text, status: status, topics: topics));
    await beforeAdd?.call();
    // Même contrat que EntryRepository.addEntry : texte gardé tel quel, absent s'il
    // est vide ou fait seulement d'espaces.
    final blank = text == null || text.trim().isEmpty;
    final now = clock();
    final entry = Entry(
      id: _nextId(),
      mood: mood,
      text: blank ? null : text,
      createdAt: now.toUtc(),
      // Décalage de l'horloge, comme le vrai dépôt : l'heure affichée ne dépend pas
      // du fuseau de la machine qui lance les tests.
      utcOffset: now.timeZoneOffset,
      analysisStatus: blank ? AnalysisStatus.skipped : status,
      topics: _inListOrder(topics),
    );
    _entries.insert(0, entry);
    _sort();
    _changes.add(entries);
    return entry;
  }

  @override
  Future<void> deleteEntry(int id) async {
    await beforeDelete?.call();
    _entries.removeWhere((e) => e.id == id);
    _changes.add(entries);
  }

  /// Enregistre directement une entrée (préparation d'un test), sans passer par
  /// [addEntry] ni [addCalls].
  Entry seed({
    required int mood,
    String? text,
    required DateTime createdAt,
    AnalysisStatus? status,
    List<Topic> topics = const [],
  }) {
    final entry = Entry(
      id: _nextId(),
      mood: mood,
      text: text,
      createdAt: createdAt.toUtc(),
      utcOffset: createdAt.timeZoneOffset,
      analysisStatus:
          status ??
          (text == null ? AnalysisStatus.skipped : AnalysisStatus.pending),
      topics: _inListOrder(topics),
    );
    _entries.add(entry);
    _sort();
    _changes.add(entries);
    return entry;
  }

  /// Les sujets sont rangés dans l'ordre de la liste (spec 010, CA4).
  static List<Topic> _inListOrder(List<Topic> topics) => [
    for (final topic in Topic.values)
      if (topics.contains(topic)) topic,
  ];

  int _nextId() => _entries.fold(0, (m, e) => e.id > m ? e.id : m) + 1;

  void _sort() => _entries.sort((a, b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });

  /// Si non nul, [allEntriesWithTags] lève cette erreur (export, spec 005).
  Object? allEntriesError;

  @override
  Future<List<Entry>> allEntriesWithTags() async {
    if (allEntriesError != null) throw allEntriesError!;
    return entries.reversed.toList();
  }

  @override
  Future<List<Entry>> latestEntries(int count) async {
    if (latestEntriesError != null) throw latestEntriesError!;
    return entries.take(count).toList();
  }

  /// Si non nul, [entriesBetween] lève cette erreur (lecture de la semaine).
  Object? entriesBetweenError;

  /// Appels à [entriesBetween], dans l'ordre, y compris ceux qui ont échoué.
  final List<({DateTime fromUtc, DateTime toUtc})> entriesBetweenCalls = [];

  /// Comme le vrai dépôt : début compris, fin exclue, de la plus ancienne à la
  /// plus récente (instant, puis identifiant), sans étiquettes ni sujets.
  @override
  Future<List<Entry>> entriesBetween(DateTime fromUtc, DateTime toUtc) async {
    entriesBetweenCalls.add((fromUtc: fromUtc, toUtc: toUtc));
    if (entriesBetweenError != null) throw entriesBetweenError!;
    return [
      for (final e in entries.reversed)
        if (!e.createdAt.isBefore(fromUtc) && e.createdAt.isBefore(toUtc))
          Entry(
            id: e.id,
            mood: e.mood,
            text: e.text,
            createdAt: e.createdAt,
            utcOffset: e.utcOffset,
            analysisStatus: e.analysisStatus,
          ),
    ];
  }

  @override
  Future<List<Entry>> pendingEntriesWithText() async => entries
      .where(
        (e) => e.analysisStatus == AnalysisStatus.pending && e.text != null,
      )
      .toList();

  @override
  Future<void> markSkipped(Iterable<int> ids) async {
    if (markSkippedError != null) throw markSkippedError!;
    final set = ids.toSet();
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (set.contains(e.id)) {
        _entries[i] = Entry(
          id: e.id,
          mood: e.mood,
          text: e.text,
          createdAt: e.createdAt,
          utcOffset: e.utcOffset,
          analysisStatus: AnalysisStatus.skipped,
          topics: e.topics,
        );
      }
    }
    _changes.add(entries);
  }

  /// Si non nul, [saveAnalysis] lève cette erreur (CA8).
  Object? saveAnalysisError;

  /// Appels à [saveAnalysis], dans l'ordre, y compris ceux qui ont échoué.
  final List<({int entryId, AnalysisResult result})> saveAnalysisCalls = [];

  @override
  Future<void> saveAnalysis(int entryId, AnalysisResult result) async {
    saveAnalysisCalls.add((entryId: entryId, result: result));
    if (saveAnalysisError != null) throw saveAnalysisError!;
    final i = _entries.indexWhere((e) => e.id == entryId);
    // Comme le vrai dépôt : supprimée, ou plus « en attente », rien à écrire
    // (CA16).
    if (i < 0) return;
    final e = _entries[i];
    if (e.analysisStatus != AnalysisStatus.pending) return;
    _entries[i] = Entry(
      id: e.id,
      mood: e.mood,
      text: e.text,
      createdAt: e.createdAt,
      utcOffset: e.utcOffset,
      analysisStatus: result is Tagged
          ? AnalysisStatus.tagged
          : AnalysisStatus.untagged,
      tags: result is Tagged ? result.tags : const [],
      topics: e.topics,
    );
    _changes.add(entries);
  }
}
