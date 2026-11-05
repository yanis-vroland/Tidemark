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

  /// Proposition du modèle déjà affichée (spec 003).
  bool modelOfferShown = false;
  final _offerChanges = StreamController<bool>.broadcast();

  @override
  Stream<bool> watchModelOfferShown() async* {
    yield modelOfferShown;
    yield* _offerChanges.stream;
  }

  @override
  Future<bool> readModelOfferShown() async => modelOfferShown;

  @override
  Future<void> setModelOfferShown() async {
    modelOfferShown = true;
    _offerChanges.add(true);
  }

  /// Bienvenue déjà vue (spec 009) ; faux par défaut, comme un premier lancement.
  bool welcomeShown = false;

  /// Si non nul, [readWelcomeShown] lève cette erreur (CA6).
  Object? welcomeReadError;

  /// Si non nul, [setWelcomeShown] lève cette erreur (CA5) ; le réglage reste faux.
  Object? welcomeWriteError;

  /// Nombre d'appels à [setWelcomeShown], y compris ceux qui ont échoué.
  int setWelcomeShownCalls = 0;

  @override
  Future<bool> readWelcomeShown() async {
    if (welcomeReadError != null) throw welcomeReadError!;
    return welcomeShown;
  }

  @override
  Future<void> setWelcomeShown() async {
    setWelcomeShownCalls++;
    if (welcomeWriteError != null) throw welcomeWriteError!;
    welcomeShown = true;
  }
}
