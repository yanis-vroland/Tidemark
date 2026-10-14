import 'entry.dart';

/// Accès aux entrées, derrière une interface : les écrans ne connaissent pas la base.
abstract interface class EntryRepository {
  /// Toutes les entrées, de la plus récente à la plus ancienne, mises à jour à chaque
  /// ajout ou suppression.
  Stream<List<Entry>> watchEntries();

  /// Enregistre une entrée saisie maintenant. Un [text] vide ou fait seulement
  /// d'espaces est enregistré comme absent (null) ; au-delà de [maxTextLength]
  /// caractères visibles, il est refusé par une [ArgumentError].
  Future<Entry> addEntry({required int mood, String? text});

  /// Supprime définitivement l'entrée [id] (RM15, RM28).
  Future<void> deleteEntry(int id);
}
