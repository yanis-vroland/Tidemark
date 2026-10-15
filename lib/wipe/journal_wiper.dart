import 'dart:io';

import '../storage/database_key.dart';

/// Accès aux fichiers de la suppression totale, injectable pour simuler une erreur.
/// Chaque opération est idempotente : une cible absente compte comme traitée.
abstract interface class WipeFiles {
  /// Crée le fichier vide [file] (et son dossier) s'il n'existe pas.
  Future<void> createFile(File file);

  /// Efface [file] s'il existe.
  Future<void> deleteFile(File file);

  /// Efface [directory] et tout son contenu s'il existe.
  Future<void> deleteDirectory(Directory directory);
}

/// [WipeFiles] sur `dart:io`.
class IoWipeFiles implements WipeFiles {
  const IoWipeFiles();

  @override
  Future<void> createFile(File file) => throw UnimplementedError();

  @override
  Future<void> deleteFile(File file) => throw UnimplementedError();

  @override
  Future<void> deleteDirectory(Directory directory) =>
      throw UnimplementedError();
}

/// Le marqueur `wipe-pending` n'a pas pu être écrit : rien n'a été effacé (CA20).
class WipeNotStartedError implements Exception {
  const WipeNotStartedError(this.cause);

  final Object cause;

  @override
  String toString() => 'WipeNotStartedError($cause)';
}

/// Une étape après le marqueur a échoué : les suivantes n'ont pas eu lieu et
/// `wipe-pending` reste (CA21, CA23).
class WipeIncompleteError implements Exception {
  const WipeIncompleteError(this.cause);

  final Object cause;

  @override
  String toString() => 'WipeIncompleteError($cause)';
}

/// Suppression totale (glossaire : `JournalWiper`, spec 005, RM12, RM42, RM43).
///
/// Étapes, dans l'ordre : marqueur `wipe-pending` ; base (fermeture par
/// [closeJournal], puis `journal.db-wal`, `-shm`, `-journal` et `journal.db`) ;
/// clé ([KeyStore.deleteAll]) ; dossier du modèle `models/` ; dossiers temporaires
/// d'export ; effacement du marqueur. Le marqueur d'installation `installed` reste.
class JournalWiper {
  JournalWiper({
    required this.folder,
    required this.cacheFolder,
    required this.keyStore,
    this.files = const IoWipeFiles(),
    this.closeJournal,
  });

  /// Dossier de la base (Application Support/tidemark).
  final Directory folder;

  /// Cache de l'app : parent des dossiers temporaires d'export.
  final Directory cacheFolder;

  final KeyStore keyStore;
  final WipeFiles files;

  /// Arrête la file d'analyse (et libère le modèle), annule un téléchargement et
  /// ferme la base, si un journal est ouvert. Appelé au début de l'étape de la
  /// base, jusqu'à ce qu'il réussisse une fois.
  final Future<void> Function()? closeJournal;

  /// Marqueur de suppression en cours.
  File get pendingMarker => File('${folder.path}/wipe-pending');

  /// Fichier de la base.
  File get databaseFile => File('${folder.path}/journal.db');

  /// Dossier du modèle local (spec 003).
  Directory get modelFolder => Directory('${folder.path}/models');

  /// Vrai si une suppression a commencé sans se terminer.
  bool get isPending => pendingMarker.existsSync();

  /// Écrit le marqueur (sinon lève [WipeNotStartedError] sans rien effacer), puis
  /// exécute les étapes comme [resume].
  Future<void> wipe() => throw UnimplementedError();

  /// Rejoue les étapes 2 à 6 : base, clé, modèle, fichiers temporaires, puis
  /// effacement du marqueur. Lève [WipeIncompleteError] à la première étape en
  /// échec, sans exécuter les suivantes.
  Future<void> resume() => throw UnimplementedError();
}
