import 'dart:io';

import 'engine.dart';
import 'labeling.dart';

/// Mesures d'un moteur sur le jeu d'entrées fictives.
class BenchResult {
  BenchResult({
    required this.engine,
    required this.modelFile,
    required this.modelBytes,
    required this.loadMs,
    required this.rssAfterLoadMb,
    required this.maxRssMb,
    required this.perEntryMs,
    required this.valid,
    required this.recalls,
    required this.rawOutputs,
  });

  final String engine;
  final String modelFile;
  final int modelBytes;
  final int loadMs;
  final int rssAfterLoadMb;
  final int maxRssMb;
  final List<int> perEntryMs;
  final int valid;
  final List<double> recalls;
  final List<String> rawOutputs;

  int get count => perEntryMs.length;

  int _percentile(double p) {
    final sorted = [...perEntryMs]..sort();
    return sorted[((sorted.length - 1) * p).round()];
  }

  double get meanRecall =>
      recalls.isEmpty ? 0 : recalls.reduce((a, b) => a + b) / recalls.length;

  Map<String, Object> toJson() => {
        'engine': engine,
        'modelFile': modelFile,
        'modelMb': (modelBytes / 1024 / 1024).round(),
        'loadMs': loadMs,
        'rssAfterLoadMb': rssAfterLoadMb,
        'maxRssMb': maxRssMb,
        'entries': count,
        'medianMs': _percentile(0.5),
        'p90Ms': _percentile(0.9),
        'validJson': '$valid/$count',
        'meanRecallOnValid': double.parse(meanRecall.toStringAsFixed(2)),
        'rawOutputs': rawOutputs,
      };
}

int _mb(int bytes) => (bytes / 1024 / 1024).round();

Future<BenchResult> runBench({
  required SpikeEngine engine,
  required String modelPath,
  required Vocabulary vocabulary,
  required List<SpikeEntry> entries,
  void Function(String)? onProgress,
}) async {
  final loadWatch = Stopwatch()..start();
  await engine.load(modelPath);
  loadWatch.stop();
  final rssAfterLoad = ProcessInfo.currentRss;

  final perEntry = <int>[];
  final recalls = <double>[];
  final raw = <String>[];
  var valid = 0;
  for (final entry in entries) {
    onProgress?.call('${engine.name} : entrée ${entry.id}/${entries.length}');
    final watch = Stopwatch()..start();
    final output = await engine.generate(buildPrompt(vocabulary, entry.text));
    watch.stop();
    perEntry.add(watch.elapsedMilliseconds);
    raw.add(output);
    final labels = parseLabels(output, vocabulary);
    if (labels != null) {
      valid++;
      recalls.add(recall(labels, entry));
    }
  }
  await engine.dispose();

  return BenchResult(
    engine: engine.name,
    modelFile: modelPath.split('/').last,
    modelBytes: File(modelPath).lengthSync(),
    loadMs: loadWatch.elapsedMilliseconds,
    rssAfterLoadMb: _mb(rssAfterLoad),
    maxRssMb: _mb(ProcessInfo.maxRss),
    perEntryMs: perEntry,
    valid: valid,
    recalls: recalls,
    rawOutputs: raw,
  );
}
