import '../analysis/mood_analyzer.dart';
import 'model_gate.dart';

/// [MoodAnalyzer] qui détient l'accès au modèle ([ModelGate]) de son chargement
/// ([prepare]) à sa libération ([release]) : tant que la file d'analyse garde le
/// modèle chargé, le bilan attend son tour (spec 006, ADR-005).
class GatedMoodAnalyzer implements MoodAnalyzer {
  GatedMoodAnalyzer(this.inner, this.gate);

  final MoodAnalyzer inner;
  final ModelGate gate;

  @override
  Future<bool> prepare() => throw UnimplementedError();

  @override
  Future<AnalysisResult> analyze(String text) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<void> release() => throw UnimplementedError();
}
