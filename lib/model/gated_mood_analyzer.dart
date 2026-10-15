import '../analysis/mood_analyzer.dart';
import 'model_gate.dart';

/// [MoodAnalyzer] qui détient l'accès au modèle ([ModelGate]) de son chargement
/// ([prepare]) à sa libération ([release]) : tant que la file d'analyse garde le
/// modèle chargé, le bilan attend son tour (spec 006, ADR-005).
class GatedMoodAnalyzer implements MoodAnalyzer {
  GatedMoodAnalyzer(this.inner, this.gate);

  final MoodAnalyzer inner;
  final ModelGate gate;

  void Function()? _release;

  @override
  Future<bool> prepare() async {
    if (_release != null) return inner.prepare();
    _release = await gate.acquire();
    var ready = false;
    try {
      ready = await inner.prepare();
    } catch (_) {
      ready = false;
    }
    if (!ready) _free();
    return ready;
  }

  @override
  Future<AnalysisResult> analyze(String text) => inner.analyze(text);

  @override
  Future<void> cancel() => inner.cancel();

  @override
  Future<void> release() async {
    try {
      await inner.release();
    } finally {
      _free();
    }
  }

  void _free() {
    final release = _release;
    _release = null;
    release?.call();
  }
}
