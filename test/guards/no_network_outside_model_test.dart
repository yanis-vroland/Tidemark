// Garde-fou RM1 (spec 003, CA25) : le téléchargement du modèle est le seul accès
// réseau de l'app. Aucun fichier de lib/ hors de lib/model/ n'utilise de client
// réseau ; `url_launcher` n'est admis qu'avec un schéma `tel:` (écran d'aide).
//
// Limite assumée (CA33) : ce garde-fou ne voit pas le code des dépendances.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Utilisations interdites hors de lib/model/, par nom.
final forbidden = <String, RegExp>{
  'HttpClient': RegExp(r'\bHttpClient\b'),
  'HttpRequest': RegExp(r'\bHttpRequest\b'),
  'Socket': RegExp(r'\bSocket\b'),
  'RawSocket': RegExp(r'\bRawSocket\b'),
  'SecureSocket': RegExp(r'\bSecureSocket\b'),
  'WebSocket': RegExp(r'\bWebSocket\b'),
  'InternetAddress': RegExp(r'\bInternetAddress\b'),
  // Ajoutés après la revue IA de la PR #22 : toute classe réseau de `dart:io`
  // (UDP, serveurs, sockets sécurisés bruts) et les paquets réseau courants.
  'classes *Socket': RegExp(r'\b\w*Socket\b'),
  'HttpServer': RegExp(r'\bHttpServer\b'),
  'RawDatagramSocket': RegExp(r'\bRawDatagramSocket\b'),
  'package:http2': RegExp(r'package:http2\b'),
  'package:web_socket_channel': RegExp(r'package:web_socket_channel\b'),
  'package:grpc': RegExp(r'package:grpc\b'),
  'Image.network': RegExp(r'\bImage\s*\.\s*network\b'),
  'NetworkImage': RegExp(r'\bNetworkImage\b'),
  'package:http': RegExp(r'package:http\b'),
  'package:dio': RegExp(r'package:dio\b'),
};

/// Remplace les commentaires par des espaces, en gardant les retours à la ligne.
String withoutComments(String source) => source.replaceAllMapped(
  RegExp(r'/\*[\s\S]*?\*/|//[^\n]*'),
  (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
);

/// Ce que [source] fait d'interdit : noms de [forbidden] trouvés, et usages de
/// `url_launcher` autres que `launchUrl(Uri(scheme: 'tel', …))`.
List<String> violations(String source) {
  final code = withoutComments(source);
  final found = <String>[
    for (final MapEntry(:key, :value) in forbidden.entries)
      if (value.hasMatch(code)) key,
  ];
  if (RegExp(r'package:url_launcher\b').hasMatch(code)) {
    final uriCalls = RegExp(r'\bUri\s*\(').allMatches(code).length;
    final telCalls = RegExp(r'''\bUri\s*\(\s*scheme\s*:\s*['"]tel['"]''')
        .allMatches(code)
        .length;
    if (uriCalls != telCalls) found.add('url_launcher : Uri sans schéma tel');
    for (final entry in {
      'url_launcher : Uri.parse': RegExp(r'\bUri\s*\.\s*(parse|tryParse)\b'),
      'url_launcher : Uri.http(s)': RegExp(r'\bUri\s*\.\s*https?\b'),
      'url_launcher : launchUrlString': RegExp(r'\blaunchUrlString\b'),
      'url_launcher : launch()': RegExp(r'\blaunch\s*\('),
      'url_launcher : adresse http(s)': RegExp(r'https?:'),
      'url_launcher : mailto ou sms': RegExp(r'\b(mailto|sms):'),
    }.entries) {
      if (entry.value.hasMatch(code)) found.add(entry.key);
    }
  }
  return found;
}

/// Fichiers de [lib] (hors `model/`) avec leurs violations, `chemin: noms`.
Map<String, List<String>> scan(Directory lib) {
  final result = <String, List<String>>{};
  for (final file
      in lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
    final relative = file.path
        .replaceAll(r'\', '/')
        .substring(lib.path.replaceAll(r'\', '/').length + 1);
    if (relative.startsWith('model/')) continue;
    final found = violations(file.readAsStringSync());
    if (found.isNotEmpty) result[relative] = found;
  }
  return result;
}

void main() {
  group('détection', () {
    final samples = {
      'HttpClient': 'final c = HttpClient();',
      'HttpRequest': 'final r = HttpRequest();',
      'Socket': 'final s = await Socket.connect(h, 80);',
      'RawSocket': 'final s = await RawSocket.connect(h, 80);',
      'SecureSocket': 'final s = await SecureSocket.connect(h, 443);',
      'WebSocket': 'final s = await WebSocket.connect(u);',
      'InternetAddress': 'final a = InternetAddress("1.2.3.4");',
      'Image.network': 'Image.network("https://x/y.png");',
      'NetworkImage': 'final i = NetworkImage("https://x/y.png");',
      'package:http': "import 'package:http/http.dart' as http;",
      'package:dio': "import 'package:dio/dio.dart';",
    };

    for (final MapEntry(key: name, value: source) in samples.entries) {
      test('CA25 : repère $name', () {
        expect(violations(source), contains(name));
      });
    }

    test('CA25 : repère un appel coupé sur deux lignes', () {
      expect(
        violations('final c =\n  HttpClient\n  ();'),
        contains('HttpClient'),
      );
      expect(violations('Image\n  .network(u);'), contains('Image.network'));
    });

    test('CA25 : ignore les commentaires et les noms qui ne font que contenir '
        'un mot interdit', () {
      expect(violations('// HttpClient est interdit ici'), isEmpty);
      expect(violations('/* Socket, WebSocket */ final a = 1;'), isEmpty);
      expect(violations('class FakeHttpClientLog {}'), isEmpty);
      expect(
        violations("import 'package:http_parser/http_parser.dart';"),
        isEmpty,
      );
      expect(
        violations("import 'dart:io';\nfinal d = Directory('x');"),
        isEmpty,
      );
    });

    test('CA25 : url_launcher avec un schéma tel: est admis', () {
      const source = '''
import 'package:url_launcher/url_launcher.dart';
Future<bool> dial(String n) => launchUrl(Uri(scheme: 'tel', path: n));
''';
      expect(violations(source), isEmpty);
    });

    final launcherViolations = {
      'Uri.parse': "launchUrl(Uri.parse('tel:3114'));",
      'adresse https': "launchUrl(Uri(scheme: 'https', host: 'example.org'));",
      'adresse http': "launchUrl(Uri(scheme: 'tel', path: 'http://x'));",
      'mailto': "launchUrl(Uri(scheme: 'mailto', path: 'a@b.c'));",
      'sms': "launchUrl(Uri(scheme: 'sms', path: '0600000000'));",
      'launchUrlString': "launchUrlString('tel:3114');",
      'Uri.https': "launchUrl(Uri.https('example.org', '/'));",
      'un tel: et un autre schéma':
          "launchUrl(Uri(scheme: 'tel', path: '1'));"
          "launchUrl(Uri(scheme: 'https', host: 'x'));",
    };
    for (final MapEntry(key: name, value: body) in launcherViolations.entries) {
      test('CA25 : url_launcher, $name est refusé', () {
        final source =
            "import 'package:url_launcher/url_launcher.dart';\n$body";

        expect(violations(source), isNotEmpty);
      });
    }

    test(
      'CA25 : sans url_launcher, un Uri ordinaire n\'est pas une violation',
      () {
        expect(violations("final u = Uri.parse('tel:3114');"), isEmpty);
      },
    );
  });

  group('portée du balayage', () {
    late Directory lib;

    setUp(() => lib = Directory.systemTemp.createTempSync('tidemark_lib_'));
    tearDown(() => lib.deleteSync(recursive: true));

    void write(String path, String content) {
      final file = File('${lib.path}/$path')..createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    test('CA25 : un fichier hors de model/ qui utilise HttpClient est '
        'signalé, à son chemin', () {
      write('main.dart', 'final c = HttpClient();');
      write('ui/screens/x.dart', 'final c = Socket;');

      expect(
        scan(lib).keys,
        unorderedEquals(['main.dart', 'ui/screens/x.dart']),
      );
    });

    test('CA25 : lib/model/ est le seul dossier exempté', () {
      write('model/model_transport.dart', 'final c = HttpClient();');
      write('model/sub/deep.dart', 'final c = Socket;');

      expect(scan(lib), isEmpty);
    });

    test('CA25 : un dossier dont le nom commence par « model » n\'est pas '
        'exempté', () {
      write('modelling/x.dart', 'final c = HttpClient();');
      write('models_ui/y.dart', 'final c = HttpClient();');
      write('ui/model/z.dart', 'final c = HttpClient();');

      expect(
        scan(lib).keys,
        unorderedEquals([
          'modelling/x.dart',
          'models_ui/y.dart',
          'ui/model/z.dart',
        ]),
      );
    });

    test('CA25 : un fichier propre n\'est pas signalé', () {
      write('ui/ok.dart', "import 'dart:io';\nfinal d = Directory('x');");

      expect(scan(lib), isEmpty);
    });
  });

  group('code de l\'app', () {
    test('CA25 : aucun fichier de lib/ hors de lib/model/ n\'utilise le '
        'réseau', () {
      expect(scan(Directory('lib')), isEmpty);
    });

    test('CA25 : le balayage voit bien le code réseau là où il est permis : '
        'lib/model/ utilise HttpClient', () {
      final transport = File('lib/model/model_transport.dart')
          .readAsStringSync();

      expect(violations(transport), contains('HttpClient'));
    });

    test('CA25 : url_launcher n\'est utilisé que par l\'écran d\'aide, avec '
        'tel:', () {
      final users = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('package:url_launcher'))
          .toList();

      expect(users, isNotEmpty);
      for (final file in users) {
        expect(violations(file.readAsStringSync()), isEmpty, reason: file.path);
        expect(file.readAsStringSync(), contains("scheme: 'tel'"));
      }
    });
  });

  group('llamadart : source du modèle (issue #31)', () {
    const import = "import 'package:llamadart/llamadart.dart' as llama;\n";

    final refused = {
      'ModelSource.url préfixé':
          "final m = llama.LlamaModel(llama.ModelSource.url("
          "Uri.parse('https://x/m.gguf')));",
      'ModelSource.huggingFace':
          "final s = ModelSource.huggingFace(repo: 'a/b', file: 'm.gguf');",
      'ModelSource.parse': "final s = llama.ModelSource.parse('https://x');",
      'ModelSource.url coupé sur deux lignes':
          'final s = llama.ModelSource\n  .url(u);',
      'loadModelFromUrl': 'await engine.loadModelFromUrl(u);',
      'loadModel avec une adresse':
          "await engine.loadModel('https://x/m.gguf');",
      'LlamaModel avec une source passée par une variable':
          'final m = llama.LlamaModel(source);',
      'projecteur passé par une variable':
          'final m = llama.LlamaModel(llama.ModelSource.path(p), '
          'projector: other);',
    };
    for (final MapEntry(key: name, value: body) in refused.entries) {
      test('issue #31 : refuse, avec import llamadart, $name', () {
        expect(llamadartViolations('$import$body'), isNotEmpty);
      });
    }

    test('issue #31 : admet une source locale, ModelSource.path', () {
      expect(
        llamadartViolations(
          '${import}final m = '
          'llama.LlamaModel(llama.ModelSource.path(modelFile.path));',
        ),
        isEmpty,
      );
    });

    test('issue #31 : admet ModelSource.path sans préfixe d\'import', () {
      expect(
        llamadartViolations(
          "import 'package:llamadart/llamadart.dart';\n"
          'final m = LlamaModel(ModelSource.path(modelFile.path));',
        ),
        isEmpty,
      );
    });

    test('issue #31 : un fichier sans import llamadart qui utilise la classe '
        'ModelSource de l\'app n\'est pas concerné', () {
      expect(
        llamadartViolations(
          "import '../model/model_source.dart';\n"
          'final ok = ModelSource.isAllowed(next);',
        ),
        isEmpty,
      );
    });

    test('issue #31 : les commentaires sont ignorés', () {
      expect(
        llamadartViolations(
          '$import// ModelSource.url(u) est interdit\n'
          '/* engine.loadModelFromUrl(u) */\n'
          'final m = llama.LlamaModel(llama.ModelSource.path(p));',
        ),
        isEmpty,
      );
    });

    final libFiles = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart')) file,
    ];
    final importers = [
      for (final file in libFiles)
        if (RegExp(r'''import\s+['"]package:llamadart/''')
            .hasMatch(file.readAsStringSync()))
          file.path.replaceAll(r'\', '/'),
    ];

    test('issue #31 : le balayage voit les fichiers qui importent llamadart '
        '(il n\'est pas vide)', () {
      expect(importers.length, greaterThanOrEqualTo(2));
      expect(
        importers,
        containsAll([
          endsWith('lib/analysis/llama_mood_analyzer.dart'),
          endsWith('lib/review/llama_review_writer.dart'),
        ]),
      );
    });

    test('issue #31 : aucun fichier de lib/, lib/model/ compris, ne crée une '
        'source de modèle autrement que par ModelSource.path', () {
      final found = {
        for (final file in libFiles)
          file.path: llamadartViolations(file.readAsStringSync()),
      }..removeWhere((_, v) => v.isEmpty);

      expect(found, isEmpty);
    });
  });
}

/// Ce qu'un fichier qui importe `package:llamadart` fait d'interdit : toute source
/// de modèle autre que `ModelSource.path(` (adresse, Hugging Face, `parse`, source
/// passée par une variable, méthodes `loadModel*`). Commentaires ignorés ; un
/// fichier sans cet import n'est pas concerné (la classe `ModelSource` de l'app,
/// `lib/model/model_source.dart`, porte le même nom). Issue #31.
List<String> llamadartViolations(String source) {
  final code = withoutComments(source);
  if (!RegExp(r'''import\s+['"]package:llamadart/''').hasMatch(code)) {
    return const [];
  }
  const localSource = r'(\w+\s*\.\s*)?ModelSource\s*\.\s*path\s*\(';
  final found = <String>[
    for (final m in RegExp(r'\bModelSource\s*\.\s*(\w+)').allMatches(code))
      if (m[1] != 'path') 'llamadart : ModelSource.${m[1]}',
    // Méthodes du moteur qui acceptent une adresse au lieu d'un chemin.
    if (RegExp(r'\bloadModel\w*\s*\(').hasMatch(code)) 'llamadart : loadModel*',
    // Le modèle (et son projecteur) reçoit sa source directement de
    // `ModelSource.path(`, jamais d'une variable construite ailleurs.
    for (final m in RegExp(
      r'\bLlamaModel\s*\(\s*(?!' + localSource + r')',
    ).allMatches(code))
      'llamadart : LlamaModel sans ModelSource.path (${m.start})',
    for (final m in RegExp(
      r'\bprojector\s*:\s*(?!' + localSource + r')',
    ).allMatches(code))
      'llamadart : projector sans ModelSource.path (${m.start})',
  ];
  return found;
}
