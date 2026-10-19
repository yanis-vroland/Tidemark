// Lecture minimale d'un PNG (en-tête IHDR et pixels 8 bits, types de couleur 2 et 6,
// sans entrelacement), pour vérifier les images générées sans dépendance.
import 'dart:io';
import 'dart:typed_data';

class PngInfo {
  PngInfo(this.width, this.height, this.bitDepth, this.colorType, this.bytes);

  final int width;
  final int height;
  final int bitDepth;

  /// 0 gris, 2 RVB (sans canal alpha), 3 palette, 4 gris + alpha, 6 RVBA.
  final int colorType;
  final Uint8List bytes;
}

const _signature = [137, 80, 78, 71, 13, 10, 26, 10];

/// Lit l'en-tête de [path] ; `null` si le fichier est absent ou n'est pas un PNG.
PngInfo? readPng(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final bytes = file.readAsBytesSync();
  if (bytes.length < 33) return null;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != _signature[i]) return null;
  }
  final data = ByteData.sublistView(bytes);
  return PngInfo(
    data.getUint32(16),
    data.getUint32(20),
    bytes[24],
    bytes[25],
    bytes,
  );
}

typedef Pixel = ({int r, int g, int b, int a});

/// Pixels du PNG, ligne par ligne ; `null` si le format n'est pas pris en charge.
List<Pixel>? decodePixels(PngInfo png) {
  if (png.bitDepth != 8 || (png.colorType != 2 && png.colorType != 6)) {
    return null;
  }
  final data = ByteData.sublistView(png.bytes);
  final idat = BytesBuilder();
  var offset = 8;
  while (offset + 8 <= png.bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(
      png.bytes.sublist(offset + 4, offset + 8),
    );
    if (type == 'IDAT') {
      idat.add(png.bytes.sublist(offset + 8, offset + 8 + length));
    }
    offset += 12 + length;
  }
  final raw = zlib.decode(idat.toBytes());
  final channels = png.colorType == 2 ? 3 : 4;
  final stride = png.width * channels;
  final out = Uint8List(png.height * stride);
  for (var y = 0; y < png.height; y++) {
    final filter = raw[y * (stride + 1)];
    for (var x = 0; x < stride; x++) {
      final value = raw[y * (stride + 1) + 1 + x];
      final left = x >= channels ? out[y * stride + x - channels] : 0;
      final up = y > 0 ? out[(y - 1) * stride + x] : 0;
      final upLeft = (x >= channels && y > 0)
          ? out[(y - 1) * stride + x - channels]
          : 0;
      final predicted = switch (filter) {
        1 => left,
        2 => up,
        3 => (left + up) >> 1,
        4 => _paeth(left, up, upLeft),
        _ => 0,
      };
      out[y * stride + x] = (value + predicted) & 0xFF;
    }
  }
  return [
    for (var i = 0; i < png.width * png.height; i++)
      (
        r: out[i * channels],
        g: out[i * channels + 1],
        b: out[i * channels + 2],
        a: channels == 4 ? out[i * channels + 3] : 255,
      ),
  ];
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/// Nombre de pixels opaques à [tolerance] près de la couleur `#rrggbb` [hex].
int countColor(List<Pixel> pixels, String hex, {int tolerance = 8}) {
  final r = int.parse(hex.substring(1, 3), radix: 16);
  final g = int.parse(hex.substring(3, 5), radix: 16);
  final b = int.parse(hex.substring(5, 7), radix: 16);
  return pixels
      .where(
        (p) =>
            p.a > 240 &&
            (p.r - r).abs() <= tolerance &&
            (p.g - g).abs() <= tolerance &&
            (p.b - b).abs() <= tolerance,
      )
      .length;
}
