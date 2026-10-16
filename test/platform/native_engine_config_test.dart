// Moteur natif llama.cpp vérifié (ADR-004, options A et B) : le hook de
// `llamadart` ne prend que les archives du dossier préparé par
// `scripts/fetch-llama-native.sh`, un seul moteur natif est embarqué, et la CI
// lance le script puis contrôle que le hook n'a rien téléchargé lui-même.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bloc `hooks.user_defines.llamadart` de `pubspec.yaml`, lignes sans commentaire.
List<String> _llamadartDefines() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexWhere((l) => l == '    llamadart:');
  expect(start, isNot(-1), reason: 'bloc hooks.user_defines.llamadart absent');
  final block = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (!line.startsWith('      ')) break;
    block.add(line.split('#').first.trim());
  }
  return block.where((l) => l.isNotEmpty).toList();
}

void main() {
  test('ADR-004 A : le hook prend llama.cpp dans le dossier vérifié, ignoré '
      'par Git', () {
    final defines = _llamadartDefines();
    expect(defines, contains('llamadart_native_path: .llamadart-native/'));
    final ignored = File('.gitignore').readAsLinesSync();
    expect(ignored, contains('/.llamadart-native/'));
  });

  test('ADR-004 décision 3 : un seul moteur natif embarqué, llama.cpp', () {
    expect(
      _llamadartDefines(),
      contains('llamadart_native_runtimes: llama_cpp'),
    );
  });

  test('ADR-004 A : aucune archive ni bibliothèque native versionnée', () {
    final tracked = Process.runSync('git', ['ls-files']).stdout as String;
    final natives = tracked
        .split('\n')
        .where((f) => RegExp(r'\.(tar\.gz|so|dylib|dll)$').hasMatch(f));
    expect(natives, isEmpty);
  });

  test('ADR-004 A et B : la CI prépare le moteur vérifié avant les tests, '
      'teste le script, et contrôle que le hook n\'a rien téléchargé', () {
    final workflow = File('.github/workflows/flutter.yml').readAsStringSync();
    final fetch = workflow.indexOf('scripts/fetch-llama-native.sh');
    final tests = workflow.indexOf('run: flutter test');
    expect(fetch, isNot(-1), reason: 'script non lancé en CI');
    expect(tests, isNot(-1));
    expect(fetch, lessThan(tests), reason: 'moteur préparé avant les tests');
    expect(workflow, contains('bash tests/fetch-llama-native.sh'));
    expect(workflow, contains('scripts/check-llama-hook-cache.sh'));
    expect(
      workflow.lastIndexOf('scripts/check-llama-hook-cache.sh'),
      greaterThan(tests),
      reason: 'contrôle du cache du hook après les tests',
    );
  });
}
