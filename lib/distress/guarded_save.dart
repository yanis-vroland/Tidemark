import '../entries/entry.dart';
import '../entries/entry_repository.dart';
import '../settings/settings_repository.dart';
import 'distress_detector.dart';

/// Résultat d'un enregistrement passé par le garde-fou.
class SaveOutcome {
  const SaveOutcome({required this.entry, required this.showHelp});

  final Entry entry;

  /// Vrai si l'écran d'aide doit s'afficher à la place de la liste (spec 002).
  final bool showHelp;
}

/// Enregistre une entrée en appliquant le garde-fou (spec 002, CA1 à CA9, CA21) :
/// détresse dans le texte ou série d'humeurs basses → statut `skipped` et écran
/// d'aide. Si l'enregistrement échoue, l'erreur remonte et rien n'est détecté.
Future<SaveOutcome> saveEntryWithGuard({
  required EntryRepository repository,
  required SettingsRepository settings,
  required int mood,
  String? text,
  DistressDetector detector = const DistressDetector(),
  DateTime Function() clock = DateTime.now,
}) => throw UnimplementedError();
