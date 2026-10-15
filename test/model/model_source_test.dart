// Source du modèle (spec 003, RM30) : forme de la constante (CA27), hôtes admis
// (CA8) et formats de taille (CA4, CA9).
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_source.dart';

void main() {
  group('forme de qwenModelSource (CA27)', () {
    test('CA27 : l\'URL est en https, sur l\'hôte huggingface.co', () {
      expect(qwenModelSource.url.scheme, 'https');
      expect(qwenModelSource.url.host, 'huggingface.co');
      expect(qwenModelSource.url.hasPort, isFalse);
    });

    test('CA27 : le chemin est celui du dépôt Qwen, avec un commit de 40 '
        'caractères hexadécimaux, jamais main', () {
      final segments = qwenModelSource.url.pathSegments;

      expect(segments.sublist(0, 3), [
        'Qwen',
        'Qwen2.5-1.5B-Instruct-GGUF',
        'resolve',
      ]);
      expect(segments[3], matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(segments[3], isNot('main'));
      expect(segments, hasLength(5));
      expect(segments.last, 'qwen2.5-1.5b-instruct-q4_k_m.gguf');
    });

    test('CA27 : ni paramètre ni fragment dans l\'URL', () {
      expect(qwenModelSource.url.hasQuery, isFalse);
      expect(qwenModelSource.url.hasFragment, isFalse);
    });

    test('CA27 : l\'empreinte compte 64 caractères hexadécimaux', () {
      expect(qwenModelSource.sha256, matches(RegExp(r'^[0-9a-fA-F]{64}$')));
    });

    test('CA27 : la taille est positive', () {
      expect(qwenModelSource.sizeBytes, greaterThan(0));
    });

    test('CA27 : le nom du fichier définitif est celui du GGUF', () {
      expect(qwenModelSource.fileName, 'qwen2.5-1.5b-instruct-q4_k_m.gguf');
    });
  });

  group('hôtes admis, ModelSource.isAllowed (CA8)', () {
    // Ajouté après le contrôle par mutation : le port 443 ne rend pas `http`
    // acceptable.
    test('CA8 : http sur le port 443 est refusé', () {
      expect(
        ModelSource.isAllowed(Uri.parse('http://huggingface.co:443/x')),
        isFalse,
      );
    });

    const allowed = [
      'https://huggingface.co/Qwen/x/resolve/abc/f.gguf',
      'https://cdn-lfs.huggingface.co/repos/ab/cd/file',
      'https://cas-bridge.xethub.hf.co/xet/abc?X-Amz-Signature=1',
      'https://us.aws.cdn.hf.co/xet-bridge-us/abc',
      'https://huggingface.co:443/x',
      'https://CDN-LFS.HuggingFace.CO/x',
      'https://a.b.c.hf.co/x',
    ];
    const refused = [
      'https://huggingface.co.evil.com/x',
      'https://evilhf.co/x',
      'https://hf.co.evil.com/x',
      'https://xhuggingface.co/x',
      'https://evilhuggingface.co/x',
      'http://huggingface.co/x',
      'http://cdn-lfs.huggingface.co/x',
      'http://cas-bridge.xethub.hf.co/x',
      'https://huggingface.co:8443/x',
      'https://cdn-lfs.huggingface.co:8080/x',
      'https://huggingface.co:80/x',
      'ftp://huggingface.co/x',
      'https://evil.com/huggingface.co',
      'https://evil.com/?host=huggingface.co',
      'https://huggingface.co@evil.com/x',
      'https://hf.co.huggingface.co.evil.com/x',
    ];

    for (final url in allowed) {
      test('CA8 : $url est admise', () {
        expect(ModelSource.isAllowed(Uri.parse(url)), isTrue);
      });
    }

    for (final url in refused) {
      test('CA8 : $url est refusée', () {
        expect(ModelSource.isAllowed(Uri.parse(url)), isFalse);
      });
    }

    test('CA8 : une adresse sans hôte n\'est pas admise', () {
      expect(ModelSource.isAllowed(Uri.parse('/api/resolve-cache/x')), isFalse);
    });

    test('CA8 : l\'URL de qwenModelSource est elle-même admise', () {
      expect(ModelSource.isAllowed(qwenModelSource.url), isTrue);
    });
  });

  group('taille en gigaoctets (CA4)', () {
    test('CA4 : la taille de qwenModelSource s\'écrit « 1,1 Go »', () {
      expect(formatGigabytes(qwenModelSource.sizeBytes), '1,1 Go');
    });

    test('CA4 : arrondie au dixième le plus proche, par le bas', () {
      expect(formatGigabytes(1240000000), '1,2 Go');
      expect(formatGigabytes(1149000000), '1,1 Go');
    });

    test('CA4 : arrondie au dixième le plus proche, par le haut', () {
      expect(formatGigabytes(1260000000), '1,3 Go');
      expect(formatGigabytes(1151000000), '1,2 Go');
    });

    test('CA4 : gigaoctets de 10⁹ octets, pas de 2³⁰', () {
      // 1 Gio = 1 073 741 824 octets : « 1,1 Go » en 10⁹, « 1,0 Gio » en 2³⁰.
      expect(formatGigabytes(1073741824), '1,1 Go');
    });

    test('CA4 : la virgule est le séparateur décimal', () {
      expect(formatGigabytes(1500000000), '1,5 Go');
      expect(formatGigabytes(1500000000), isNot(contains('.')));
    });
  });

  group('mégaoctets reçus (CA9)', () {
    test('CA9 : 312 Mo, arrondis à l\'inférieur', () {
      expect(formatMegabytes(312000000), '312 Mo');
      expect(formatMegabytes(312500000), '312 Mo');
      expect(formatMegabytes(312999999), '312 Mo');
    });

    test('CA9 : mégaoctets de 10⁶ octets, pas de 2²⁰', () {
      expect(formatMegabytes(1000000), '1 Mo');
      expect(formatMegabytes(1048575), '1 Mo');
    });

    test('CA9 : moins d\'un mégaoctet s\'écrit « 0 Mo »', () {
      expect(formatMegabytes(0), '0 Mo');
      expect(formatMegabytes(999999), '0 Mo');
    });

    test('CA9 : 999 Mo', () {
      expect(formatMegabytes(999999999), '999 Mo');
    });
  });
}
