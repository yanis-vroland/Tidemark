import '../analysis/mood_analyzer.dart';
import 'entry.dart';

/// Accès aux entrées, derrière une interface : les écrans ne connaissent pas la base.
abstract interface class EntryRepository {
  /// Toutes les entrées, de la plus récente à la plus ancienne, mises à jour à chaque
  /// ajout ou suppression.
  Stream<List<Entry>> watchEntries();

  /// Enregistre une entrée saisie maintenant. Un [text] vide ou fait seulement
  /// d'espaces est enregistré comme absent (null) ; au-delà de [maxTextLength]
  /// caractères visibles, il est refusé par une [ArgumentError]. [status] est décidé
  /// par l'appelant (garde-fou, spec 002) : `pending` ou `skipped` ; une entrée sans
  /// texte est toujours `skipped` (RM24).
  Future<Entry> addEntry({
    required int mood,
    String? text,
    AnalysisStatus status = AnalysisStatus.pending,
  });

  /// Les [count] entrées les plus récentes, de la plus récente à la plus ancienne
  /// (même ordre que [watchEntries]).
  Future<List<Entry>> latestEntries(int count);

  /// Entrées « en attente » qui ont un texte (vérification au démarrage, spec 002).
  Future<List<Entry>> pendingEntriesWithText();

  /// Passe les entrées [ids] au statut « non analysée » (détresse, RM17).
  Future<void> markSkipped(Iterable<int> ids);

  /// Enregistre le résultat de l'analyse de [entryId] (spec 004) : étiquettes et
  /// statut « étiquetée » dans une même transaction, ou statut « sans étiquette ».
  /// Sans effet si l'entrée n'existe plus (CA16).
  Future<void> saveAnalysis(int entryId, AnalysisResult result);

  /// Toutes les entrées et leurs étiquettes, de la plus ancienne à la plus récente
  /// (instant de saisie, puis identifiant), pour l'export (spec 005).
  Future<List<Entry>> allEntriesWithTags();

  /// Supprime définitivement l'entrée [id] (RM15, RM28).
  Future<void> deleteEntry(int id);
}
