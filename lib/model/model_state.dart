/// États du modèle local (spec 003, « États du modèle »).
library;

/// Statut du modèle local (glossaire : `LocalModel`).
enum LocalModelStatus { absent, downloading, ready }

/// Cause du dernier échec de téléchargement (CA15, CA17, CA18).
enum DownloadFailure {
  /// Connexion, statut HTTP, redirection refusée, délai, fichier trop court.
  network,

  /// Empreinte ou taille fausses : le fichier reçu n'est pas le bon.
  checksum,

  /// Écriture impossible : stockage plein ou dossier inaccessible.
  storage,
}

/// État complet exposé aux écrans.
sealed class ModelState {
  const ModelState();

  LocalModelStatus get status;
}

/// Aucun fichier vérifié ; [failure] est la cause du dernier échec, s'il vient
/// d'avoir lieu.
class ModelAbsent extends ModelState {
  const ModelAbsent({this.failure});

  final DownloadFailure? failure;

  @override
  LocalModelStatus get status => LocalModelStatus.absent;
}

/// Transfert en cours ([verifying] faux) ou vérification de l'empreinte.
class ModelDownloading extends ModelState {
  const ModelDownloading({
    required this.receivedBytes,
    required this.totalBytes,
    this.verifying = false,
  });

  final int receivedBytes;
  final int totalBytes;
  final bool verifying;

  @override
  LocalModelStatus get status => LocalModelStatus.downloading;
}

/// Fichier vérifié, à son nom définitif.
class ModelReady extends ModelState {
  const ModelReady({required this.path});

  final String path;

  @override
  LocalModelStatus get status => LocalModelStatus.ready;
}
