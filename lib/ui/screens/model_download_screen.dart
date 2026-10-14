import 'package:flutter/material.dart';

import '../../model/model_downloader.dart';

/// Écran du modèle (spec 003) : proposition, progression, vérification, échec, prêt.
class ModelDownloadScreen extends StatelessWidget {
  const ModelDownloadScreen({super.key, required this.downloader});

  final ModelDownloader downloader;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
