import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path_provider/path_provider.dart';

import 'bench.dart';
import 'engine.dart';
import 'engines.dart';
import 'labeling.dart';

// Choix de la mesure au lancement :
// flutter run --dart-define=ENGINE=llamadart --dart-define=MODEL=<fichier> [--dart-define=CONSTRAINED=true]
const _engine = String.fromEnvironment('ENGINE', defaultValue: 'llamadart');
const _model = String.fromEnvironment('MODEL');
const _constrained = bool.fromEnvironment('CONSTRAINED');
const _limit = int.fromEnvironment('LIMIT', defaultValue: 20);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  runApp(const SpikeApp());
}

/// Dossier où le modèle est déposé avant la mesure (adb push ou simctl).
Future<Directory> modelDirectory() async => Platform.isAndroid
    ? (await getExternalStorageDirectory())!
    : await getApplicationDocumentsDirectory();

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});

  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  String _status = 'Préparation…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _log(String message) {
    debugPrint('TIDEMARK $message');
    if (mounted) setState(() => _status = message);
  }

  Future<void> _run() async {
    try {
      final data = jsonDecode(
        await rootBundle.loadString('assets/entries.json'),
      ) as Map<String, dynamic>;
      final vocabulary = Vocabulary.fromJson(
        data['vocabulary'] as Map<String, dynamic>,
      );
      final entries = (data['entries'] as List)
          .map((e) => SpikeEntry.fromJson(e as Map<String, dynamic>))
          .take(_limit)
          .toList();
      final dir = await modelDirectory();
      final modelPath = '${dir.path}/$_model';
      if (!File(modelPath).existsSync()) {
        _log('ERREUR modèle absent : $modelPath');
        return;
      }
      final SpikeEngine engine = switch (_engine) {
        'edge' => EdgeAiEngine(ModelType.qwen3),
        _ => LlamadartEngine(vocabulary, constrained: _constrained),
      };
      _log('Chargement de $_model avec ${engine.name}');
      final result = await runBench(
        engine: engine,
        modelPath: modelPath,
        vocabulary: vocabulary,
        entries: entries,
        onProgress: _log,
      );
      debugPrint('TIDEMARK_RESULT ${jsonEncode(result.toJson())}');
      _log(
        'Terminé : ${result.toJson()['validJson']} JSON valides, '
        'médiane ${result.toJson()['medianMs']} ms',
      );
    } catch (error, stack) {
      _log('ERREUR $error');
      debugPrint('$stack');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(_status)),
      ),
    ),
  );
}
