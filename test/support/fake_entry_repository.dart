import 'dart:async';

import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/entry_repository.dart';

/// Dépôt factice en mémoire, sans base. [beforeAdd] permet de simuler un enregistrement
/// lent (attendre un `Completer`) ou en échec (lever une exception).
class FakeEntryRepository implements EntryRepository {
  FakeEntryRepository({this.beforeAdd, this.beforeDelete, this.watchError});

  /// Appelé au début de chaque [addEntry] ; s'il lève, l'entrée n'est pas enregistrée.
  Future<void> Function()? beforeAdd;

  /// Appelé au début de chaque [deleteEntry] ; s'il lève, rien n'est supprimé.
  Future<void> Function()? beforeDelete;

  /// Si non nul, [watchEntries] émet cette erreur au lieu des entrées.
  Object? watchError;

  /// Flux en attente de premier résultat, pour montrer l'état de chargement.
  bool neverEmit = false;

  /// Appels à [addEntry], dans l'ordre, y compris ceux qui ont échoué.
  final List<({int mood, String? text})> addCalls = [];

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

  @override
  Future<Entry> addEntry({required int mood, String? text}) async {
    addCalls.add((mood: mood, text: text));
    await beforeAdd?.call();
    // Même contrat que EntryRepository.addEntry : texte gardé tel quel, absent s'il
    // est vide ou fait seulement d'espaces.
    final blank = text == null || text.trim().isEmpty;
    final entry = Entry(
      id: _entries.length + 1,
      mood: mood,
      text: blank ? null : text,
      createdAt: DateTime.utc(2026, 10, 14, 19, 40),
      utcOffset: const Duration(hours: 2),
      analysisStatus: blank ? AnalysisStatus.skipped : AnalysisStatus.pending,
    );
    _entries.insert(0, entry);
    _changes.add(entries);
    return entry;
  }

  @override
  Future<void> deleteEntry(int id) async {
    await beforeDelete?.call();
    _entries.removeWhere((e) => e.id == id);
    _changes.add(entries);
  }
}
