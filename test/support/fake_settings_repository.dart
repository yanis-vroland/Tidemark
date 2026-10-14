import 'dart:async';

import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/settings/settings_repository.dart';

/// Réglages factices en mémoire. [readError] et [writeError] simulent une lecture ou
/// un enregistrement en échec ; [neverEmit] laisse l'écran en chargement.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([this.value = LowMoodSensitivity.normal]);

  LowMoodSensitivity value;
  Object? readError;
  Object? writeError;
  bool neverEmit = false;

  /// Degrés passés à [setLowMoodSensitivity], y compris ceux qui ont échoué.
  final List<LowMoodSensitivity> setCalls = [];

  final _changes = StreamController<LowMoodSensitivity>.broadcast();

  @override
  Stream<LowMoodSensitivity> watchLowMoodSensitivity() async* {
    if (neverEmit) await Completer<void>().future;
    if (readError != null) throw readError!;
    yield value;
    yield* _changes.stream;
  }

  @override
  Future<LowMoodSensitivity> readLowMoodSensitivity() async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> setLowMoodSensitivity(LowMoodSensitivity sensitivity) async {
    setCalls.add(sensitivity);
    if (writeError != null) throw writeError!;
    value = sensitivity;
    _changes.add(value);
  }
}
