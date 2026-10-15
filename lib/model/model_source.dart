/// Source du modèle local (spec 003, RM30) : un seul fournisseur, Hugging Face, une
/// révision épinglée, une empreinte vérifiée.
class ModelSource {
  const ModelSource({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.fileName,
  });

  /// URL HTTPS épinglée sur un commit du dépôt Hugging Face.
  final Uri url;

  /// Empreinte SHA-256 du fichier, en hexadécimal minuscule.
  final String sha256;

  /// Taille exacte du fichier, en octets.
  final int sizeBytes;

  /// Nom du fichier définitif sur le téléphone.
  final String fileName;

  /// Vrai si [url] peut être suivie : `https`, port par défaut, hôte
  /// `huggingface.co` ou finissant par `.huggingface.co` ou `.hf.co`.
  static bool isAllowed(Uri url) {
    if (url.scheme != 'https' || url.port != 443 || url.userInfo.isNotEmpty) {
      return false;
    }
    final host = url.host.toLowerCase();
    // Comparaison par suffixe, point compris : `evilhf.co` est refusé.
    return host == 'huggingface.co' ||
        host.endsWith('.huggingface.co') ||
        host.endsWith('.hf.co');
  }
}

/// Qwen2.5-1.5B-Instruct, GGUF Q4_K_M (ADR-001), révision du 2024-09-20 du dépôt
/// `Qwen/Qwen2.5-1.5B-Instruct-GGUF`. Taille et empreinte relevées sur Hugging Face
/// le 2026-10-14, puis vérifiées par un téléchargement (`shasum -a 256`).
final qwenModelSource = ModelSource(
  url: Uri.parse(
    'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/'
    '91cad51170dc346986eccefdc2dd33a9da36ead9/'
    'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  ),
  sha256: '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e',
  sizeBytes: 1117320736,
  fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
);

/// Taille en gigaoctets (10⁹ octets), arrondie au dixième, avec une virgule :
/// « 1,1 Go » (spec 003, CA4).
String formatGigabytes(int bytes) {
  final tenths = (bytes / 1e8).round();
  return '${tenths ~/ 10},${tenths % 10} Go';
}

/// Mégaoctets reçus (10⁶ octets), arrondis à l'inférieur : « 312 Mo » (CA9).
String formatMegabytes(int bytes) {
  final digits = '${bytes ~/ 1000000}';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer Mo';
}
