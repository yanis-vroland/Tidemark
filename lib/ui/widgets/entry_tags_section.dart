import 'package:flutter/material.dart';

import '../../analysis/analysis_queue.dart';
import '../../analysis/mood_analyzer.dart';
import '../../entries/entry.dart';
import '../../model/model_downloader.dart';
import '../../model/model_source.dart';
import '../../model/model_state.dart';
import '../analysis_scope.dart';
import '../screens/model_download_screen.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'loading_note.dart';
import 'tag_chip.dart';

/// Phrase de l'entrée en cours d'analyse (spec 004, CA20, CA22).
const analysingText = 'Analyse en cours sur ton téléphone…';

/// Section « Étiquettes » du détail d'une entrée (spec 004, CA21 à CA25, CA31).
/// Absente pour une entrée « non analysée » : rien n'y trahit une détresse (CA25).
class EntryTagsSection extends StatelessWidget {
  const EntryTagsSection({super.key, required this.entry, this.downloader});

  final Entry entry;
  final ModelDownloader? downloader;

  @override
  Widget build(BuildContext context) {
    final body = switch (entry.analysisStatus) {
      AnalysisStatus.skipped => null,
      AnalysisStatus.tagged => _Tagged(tags: entry.tags),
      AnalysisStatus.untagged => const _Muted(
        "Aucune étiquette n'a été proposée pour cette entrée.",
      ),
      AnalysisStatus.pending => _Pending(entry: entry, downloader: downloader),
    };
    if (body == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TidemarkSpacing.space6),
        Semantics(
          header: true,
          child: Text(
            'Étiquettes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: TidemarkSpacing.space3),
        body,
      ],
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TidemarkTypography.body.copyWith(color: context.colors.inkMuted),
  );
}

class _Tagged extends StatelessWidget {
  const _Tagged({required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget line(String title, List<Tag> tags) => Semantics(
      label: '$title : ${tags.map((t) => t.label).join(', ')}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TidemarkTypography.label.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: TidemarkSpacing.space1),
          TagChips(tags: tags),
          const SizedBox(height: TidemarkSpacing.space3),
        ],
      ),
    );
    final emotions = tags.where((t) => t.kind == TagKind.emotion).toList();
    final themes = tags.where((t) => t.kind == TagKind.theme).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (emotions.isNotEmpty) line('Émotions', emotions),
        if (themes.isNotEmpty) line('Thèmes', themes),
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: TidemarkSize.iconSm,
              color: colors.inkMuted,
            ),
            const SizedBox(width: TidemarkSpacing.space1),
            Expanded(
              child: Text(
                'Analysé sur ton téléphone',
                style: TidemarkTypography.caption.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending({required this.entry, required this.downloader});

  final Entry entry;
  final ModelDownloader? downloader;

  @override
  Widget build(BuildContext context) {
    final queue = AnalysisScope.maybeOf(context);
    if (queue != null && queue.currentEntryId == entry.id) {
      return const LoadingNote(text: analysingText);
    }
    if (queue?.state == AnalysisQueueState.unavailable) {
      return const _Muted(
        "Pas encore analysée : le modèle n'a pas pu être chargé. Nouvel essai au "
        'prochain lancement de Tidemark.',
      );
    }
    final model = downloader;
    if (model == null) return const SizedBox.shrink();
    return StreamBuilder<ModelState>(
      stream: model.watch(),
      initialData: model.current,
      builder: (context, snapshot) => switch (snapshot.data) {
        ModelReady() => const _Muted(
          'En attente d\'analyse sur ton téléphone.',
        ),
        ModelDownloading() => const _Muted(
          'Pas encore analysée : le modèle est en cours de téléchargement.',
        ),
        _ => _Absent(downloader: model),
      },
    );
  }
}

class _Absent extends StatelessWidget {
  const _Absent({required this.downloader});

  final ModelDownloader downloader;

  @override
  Widget build(BuildContext context) {
    final size = formatGigabytes(qwenModelSource.sizeBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Muted(
          "Pas encore analysée : le modèle d'analyse n'est pas sur ton téléphone.",
        ),
        const SizedBox(height: TidemarkSpacing.space3),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ModelDownloadScreen(downloader: downloader),
            ),
          ),
          icon: const Icon(Icons.download, size: TidemarkSize.iconButton),
          label: Text('Télécharger le modèle ($size)'),
        ),
      ],
    );
  }
}
