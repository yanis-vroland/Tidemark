import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tidemark/export/share_sheet.dart';

/// Un appel à [FakeShareSheet.shareFile], avec le fichier tel qu'il était à ce
/// moment-là : l'export l'efface ensuite.
class SharedFile {
  SharedFile({required this.path, required this.mimeType, required this.bytes});

  final String path;
  final String mimeType;

  /// Contenu du fichier lu au moment de l'appel ; `null` si le fichier n'existait
  /// pas.
  final List<int>? bytes;

  String get name => path.split(Platform.pathSeparator).last;

  /// Contenu décodé en UTF-8 ; échoue si le fichier n'existait pas.
  String get content => const Utf8Decoder().convert(bytes!);
}

/// Feuille de partage factice (spec 005, « Données ») : garde chaque appel avec le
/// contenu du fichier, peut lever une erreur ou rester « ouverte » tant que [hold]
/// n'est pas complété. Aucune feuille du système.
class FakeShareSheet implements ShareSheet {
  /// Appels à [shareFile], dans l'ordre, y compris ceux qui ont échoué.
  final List<SharedFile> shared = [];

  /// Si non nul, [shareFile] lève cette erreur (ouverture de la feuille en échec).
  Object? error;

  /// Si non nul, [shareFile] ne rend la main que quand il est complété : la feuille
  /// est encore ouverte.
  Completer<void>? hold;

  /// Appelé au moment de l'appel, avant l'attente de [hold] : permet de regarder
  /// l'état des dossiers pendant que la feuille est ouverte.
  void Function(File file)? onShare;

  @override
  Future<void> shareFile(File file, {required String mimeType}) async {
    shared.add(
      SharedFile(
        path: file.path,
        mimeType: mimeType,
        bytes: file.existsSync() ? file.readAsBytesSync() : null,
      ),
    );
    onShare?.call(file);
    if (error != null) throw error!;
    final gate = hold;
    if (gate != null) await gate.future;
  }
}
