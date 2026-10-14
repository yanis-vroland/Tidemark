import 'dart:convert';

import 'package:flutter_edge_ai/flutter_edge_ai.dart' hide ModelSource;
import 'package:llamadart/llamadart.dart' hide ModelFileType, ToolChoice;

import 'engine.dart';
import 'labeling.dart';

/// llama.cpp par `llamadart` : fichier GGUF, sortie contrainte par un schéma JSON
/// quand [constrained] est vrai.
class LlamadartEngine implements SpikeEngine {
  LlamadartEngine(
    this.vocabulary, {
    required this.constrained,
    this.gpuLayers = 99,
  });

  final Vocabulary vocabulary;
  final bool constrained;

  /// 0 : processeur seul.
  final int gpuLayers;
  final LlamaEngine _engine = LlamaEngine(LlamaBackend());

  @override
  String get name => constrained ? 'llamadart+schema' : 'llamadart';

  @override
  Future<void> load(String modelPath) => _engine.setModel(
    LlamaModel(ModelSource.path(modelPath)),
    params: ModelParams(gpuLayers: gpuLayers),
  );

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
              'json_schema': {'schema': labelSchema(vocabulary)},
            }
          : null,
    );
    return completion.text;
  }

  @override
  Future<void> dispose() => _engine.dispose();
}

/// LiteRT-LM par `flutter_edge_ai` : fichier .litertlm, sortie libre, ou
/// contrainte par un appel de fonction quand [useTools] est vrai.
class EdgeAiEngine implements SpikeEngine {
  EdgeAiEngine(this.vocabulary, this.modelType, {required this.useTools});

  final Vocabulary vocabulary;
  final ModelType modelType;
  final bool useTools;
  InferenceModel? _model;

  @override
  String get name => useTools ? 'flutter_edge_ai+tools' : 'flutter_edge_ai';

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
      tools: useTools
          ? [
              Tool(
                name: 'tag_entry',
                description:
                    "Enregistre les étiquettes d'une entrée de journal.",
                parameters: labelSchema(vocabulary),
              ),
            ]
          : const [],
      supportsFunctionCalls: useTools,
      toolChoice: useTools ? ToolChoice.required : ToolChoice.auto,
    );
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final reply = StringBuffer();
    await for (final response in chat.generateChatResponseAsync()) {
      switch (response) {
        case TextResponse(:final token):
          reply.write(token);
        case FunctionCallResponse(:final args):
          reply.write(jsonEncode(args));
        default:
      }
    }
    return reply.toString();
  }

  @override
  Future<void> dispose() async => _model?.close();
}
