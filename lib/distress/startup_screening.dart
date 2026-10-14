import '../entries/entry_repository.dart';
import 'distress_detector.dart';

/// Vérification au démarrage des entrées « en attente » avec un texte (spec 002,
/// CA15, CA16, RM5) : celles en détresse passent en « non analysée ». N'affiche rien
/// et ne lève jamais : une erreur laisse la vérification au démarrage suivant.
Future<void> screenPendingEntries(
  EntryRepository repository, {
  DistressDetector detector = const DistressDetector(),
}) async {
  try {
    final pending = await repository.pendingEntriesWithText();
    final distressed = [
      for (final entry in pending)
        if (detector.detectInText(entry.text!)) entry.id,
    ];
    if (distressed.isNotEmpty) await repository.markSkipped(distressed);
  } catch (_) {
    // Rien n'est perdu : les entrées restent « en attente » et le lot G les
    // revérifie avant toute analyse (spec 002, « Hors périmètre »).
  }
}
