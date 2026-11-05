import 'package:flutter/material.dart';

import '../../model/model_downloader.dart';
import '../../model/model_source.dart';
import '../../model/model_state.dart';
import '../screens/model_download_screen.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'model_progress_bar.dart';

/// Section « Analyse sur le téléphone » des Réglages (spec 003, CA23, CA24) : état du
/// modèle, mis à jour sans quitter l'écran.
class ModelSettingsSection extends StatefulWidget {
  const ModelSettingsSection({super.key, required this.downloader});

  final ModelDownloader downloader;

  @override
  State<ModelSettingsSection> createState() => _ModelSettingsSectionState();
}

class _ModelSettingsSectionState extends State<ModelSettingsSection> {
  late final Stream<ModelState> _states = widget.downloader.watch();
  final String _size = formatGigabytes(qwenModelSource.sizeBytes);

  void _open() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ModelDownloadScreen(downloader: widget.downloader),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TidemarkTypography.body.copyWith(color: colors.inkMuted);
    return StreamBuilder<ModelState>(
      stream: _states,
      initialData: widget.downloader.current,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const ModelAbsent();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Analyse sur le téléphone',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: TidemarkSpacing.space3),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(TidemarkSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Modèle d'analyse",
                      style: TidemarkTypography.headline,
                    ),
                    ...switch (state) {
                      ModelAbsent() => [
                        Text('Non téléchargé · $_size', style: muted),
                        const SizedBox(height: TidemarkSpacing.space2),
                        Text(
                          'Sans lui, tes entrées sont enregistrées sans '
                          'étiquettes.',
                          style: muted,
                        ),
                        const SizedBox(height: TidemarkSpacing.space3),
                        FilledButton.icon(
                          onPressed: _open,
                          icon: const Icon(
                            Icons.download,
                            size: TidemarkSize.iconButton,
                          ),
                          label: Text('Télécharger le modèle ($_size)'),
                        ),
                      ],
                      ModelDownloading(
                        :final receivedBytes,
                        :final totalBytes,
                        :final verifying,
                      ) =>
                        () {
                          final percent = verifying
                              ? 100
                              : percentOf(receivedBytes, totalBytes);
                          return [
                            Text('Téléchargement : $percent %', style: muted),
                            const SizedBox(height: TidemarkSpacing.space2),
                            ModelProgressBar(percent: percent),
                            const SizedBox(height: TidemarkSpacing.space2),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _open,
                                child: const Text('Voir le téléchargement'),
                              ),
                            ),
                          ];
                        }(),
                      ModelReady() => [
                        Text('Prêt · $_size sur ton téléphone', style: muted),
                        const SizedBox(height: TidemarkSpacing.space2),
                        Text(
                          'Tes entrées sont analysées sur ton téléphone, sans '
                          'réseau.',
                          style: muted,
                        ),
                      ],
                    },
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
