import 'package:flutter_edge_ai/flutter_edge_ai.dart' hide ModelSource;
import 'package:llamadart/llamadart.dart' hide ModelFileType;

import 'engine.dart';
import 'labeling.dart';

/// llama.cpp par `llamadart` : fichier GGUF, sortie contrainte par un schéma JSON
/// quand [constrained] est vrai.
class LlamadartEngine implements SpikeEngine {
  LlamadartEngine(this.vocabulary, {required this.constrained});

  final Vocabulary vocabulary;
  final bool constrained;
  final LlamaEngine _engine = LlamaEngine(LlamaBackend());

  @override
  String get name => constrained ? 'llamadart+schema' : 'llamadart';

  @override
  Future<void> load(String modelPath) => _engine.setModel(
    LlamaModel(ModelSource.path(modelPath)),
    params: const ModelParams(gpuLayers: 99),
  );

  Map<String, dynamic> get _schema => {
    'type': 'object',
    'properties': {
      'emotions': {
        'type': 'array',
        'items': {'enum': vocabulary.emotions},
        'minItems': 1,
        'maxItems': 3,
      },
      'themes': {
        'type': 'array',
        'items': {'enum': vocabulary.themes},
        'minItems': 1,
        'maxItems': 2,
      },
    },
    'required': ['emotions', 'themes'],
    'additionalProperties': false,
  };

  @override
  Future<String> generate(String prompt) async {
    // Une session neuve par entrée : aucun historique partagé.
    final session = ChatSession(_engine);
    final completion = await session.send(
      prompt,
      params: const GenerationParams(maxTokens: 128, temp: 0.2),
      enableThinking: false,
      responseFormat: constrained
          ? {
              'type': 'json_schema',
              'json_schema': {'schema': _schema},
            }
          : null,
    );
    return completion.text;
  }

  @override
  Future<void> dispose() => _engine.dispose();
}

/// LiteRT-LM par `flutter_edge_ai` : fichier .litertlm, sortie libre.
class EdgeAiEngine implements SpikeEngine {
  EdgeAiEngine(this.modelType);

  final ModelType modelType;
  InferenceModel? _model;

  @override
  String get name => 'flutter_edge_ai';

  @override
  Future<void> load(String modelPath) async {
    await FlutterEdgeAi.installModel(
      modelType: modelType,
      fileType: ModelFileType.litertlm,
    ).fromFile(modelPath).install();
    _model = await FlutterEdgeAi.getActiveModel(maxTokens: 1024);
  }

  @override
  Future<String> generate(String prompt) async {
    final chat = await _model!.createChat(
      temperature: 0.2,
      maxOutputTokens: 128,
      modelType: modelType,
    );
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final reply = StringBuffer();
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) reply.write(response.token);
    }
    return reply.toString();
  }

  @override
  Future<void> dispose() async => _model?.close();
}
