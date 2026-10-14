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
}) async {
  final inText = text != null && detector.detectInText(text);
  var inSeries = false;
  if (mood == 1) {
    try {
      inSeries = await _completesSeries(
        repository,
        settings,
        detector,
        mood,
        clock,
      );
    } catch (_) {
      // Série illisible : l'entrée est enregistrée quand même, et un texte en
      // détresse ouvre toujours l'écran d'aide (spec 002, cas limites).
    }
  }
  final distress = inText || inSeries;
  final entry = await repository.addEntry(
    mood: mood,
    text: text,
    status: distress ? AnalysisStatus.skipped : AnalysisStatus.pending,
  );
  return SaveOutcome(entry: entry, showHelp: distress);
}

/// La nouvelle entrée, saisie maintenant, complète-t-elle une série ? Évalué avant
/// l'enregistrement, pour que l'entrée soit enregistrée d'emblée avec son statut.
Future<bool> _completesSeries(
  EntryRepository repository,
  SettingsRepository settings,
  DistressDetector detector,
  int mood,
  DateTime Function() clock,
) async {
  LowMoodSensitivity sensitivity;
  try {
    sensitivity = await settings.readLowMoodSensitivity();
  } catch (_) {
    // Le garde-fou ne se désactive jamais sur une erreur (CA21, RM29).
    sensitivity = LowMoodSensitivity.normal;
  }
  final previous = await repository.latestEntries(sensitivity.entryCount - 1);
  final now = clock();
  // À la seconde, comme l'entrée enregistrée (`addEntry`).
  final utc = now.toUtc();
  final candidate = Entry(
    id: -1,
    mood: mood,
    text: null,
    createdAt: DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    ),
    utcOffset: now.timeZoneOffset,
    analysisStatus: AnalysisStatus.pending,
  );
  return detector.detectLowMoodSeries([candidate, ...previous], sensitivity);
}
