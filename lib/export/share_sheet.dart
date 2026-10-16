import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Feuille de partage du système (glossaire : `ShareSheet`, ADR-003) : seule voie
/// de sortie du fichier d'export (RM23).
abstract interface class ShareSheet {
  /// Ouvre la feuille de partage avec le seul fichier [file], de type [mimeType] ;
  /// se termine quand elle se ferme, que la personne ait partagé ou annulé. Lève une
  /// exception si elle ne peut pas s'ouvrir.
  Future<void> shareFile(File file, {required String mimeType});
}

/// [ShareSheet] sur le paquet `share_plus` 13.3.1 (ADR-003) :
/// `UIActivityViewController` sur iOS, `Intent.ACTION_SEND` sur Android. Aucun
/// accès réseau.
class SharePlusShareSheet implements ShareSheet {
  const SharePlusShareSheet();

  @override
  Future<void> shareFile(File file, {required String mimeType}) async {
    // Le résultat (partagé, annulé, indisponible) ne change rien : le fichier est
    // effacé dans tous les cas (spec 005, règle 2.5).
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
  }
}
