import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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

/// Phrase de l'entrée « sans étiquette » (spec 004, CA24).
const noTagsText = "Aucune étiquette n'a été proposée pour cette entrée.";

/// Annonce de fin d'analyse au lecteur d'écran (spec 004, CA28) : « Analyse
/// terminée. », puis les étiquettes ou l'absence d'étiquette.
String analysisFinishedMessage(Entry entry) {
  if (entry.analysisStatus != AnalysisStatus.tagged) {
    return 'Analyse terminée. $noTagsText';
  }
  String line(String title, TagKind kind) {
    final labels = [
      for (final tag in entry.tags)
        if (tag.kind == kind) tag.label,
    ];
    return labels.isEmpty ? '' : ' $title : ${labels.join(', ')}.';
  }

  return 'Analyse terminée.'
      '${line('Émotions', TagKind.emotion)}${line('Thèmes', TagKind.theme)}';
}

/// Section « Étiquettes » du détail d'une entrée (spec 004, CA21 à CA25, CA31).
/// Absente pour une entrée « non analysée » : rien n'y trahit une détresse (CA25).
/// Quand l'entrée affichée passe d'« en attente » à « étiquetée » ou « sans
/// étiquette », la fin de l'analyse est annoncée (CA28) : annonce explicite sur
/// iOS, région vive sur le nouveau statut ailleurs (Android), jamais les deux.
class EntryTagsSection extends StatefulWidget {
  const EntryTagsSection({super.key, required this.entry, this.downloader});

  final Entry entry;
  final ModelDownloader? downloader;

  @override
  State<EntryTagsSection> createState() => _EntryTagsSectionState();
}

class _EntryTagsSectionState extends State<EntryTagsSection> {
  /// L'analyse de l'entrée s'est terminée pendant que la section était affichée.
  bool _finished = false;

  static bool _isFinal(AnalysisStatus status) =>
      status == AnalysisStatus.tagged || status == AnalysisStatus.untagged;

  @override
  void didUpdateWidget(EntryTagsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entry = widget.entry;
    if (oldWidget.entry.id != entry.id) {
      _finished = false;
      return;
    }
    if (oldWidget.entry.analysisStatus != AnalysisStatus.pending ||
        !_isFinal(entry.analysisStatus)) {
      return;
    }
    _finished = true;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final view = View.of(context);
      final direction = Directionality.of(context);
      final message = analysisFinishedMessage(entry);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Rien n'est dit à voix haute si le détail n'est plus à l'écran : écran
        // quitté, feuille ou écran par-dessus, app pas au premier plan.
        if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
        unawaited(SemanticsService.sendAnnouncement(view, message, direction));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    Widget? body = switch (entry.analysisStatus) {
      AnalysisStatus.skipped => null,
      AnalysisStatus.tagged => _Tagged(tags: entry.tags),
      AnalysisStatus.untagged => const _Muted(noTagsText),
      AnalysisStatus.pending => _Pending(
        entry: entry,
        downloader: widget.downloader,
      ),
    };
    if (body == null) return const SizedBox.shrink();
    if (_finished &&
        _isFinal(entry.analysisStatus) &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      body = Semantics(container: true, liveRegion: true, child: body);
    }
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
    return _ModelStatus(downloader: model);
  }
}

/// État du modèle pour une entrée qui attend son tour (CA22, CA23). Le flux du
/// modèle est créé une fois : une reconstruction ne le réabonne pas (issue #32).
class _ModelStatus extends StatefulWidget {
  const _ModelStatus({required this.downloader});

  final ModelDownloader downloader;

  @override
  State<_ModelStatus> createState() => _ModelStatusState();
}

class _ModelStatusState extends State<_ModelStatus> {
  late Stream<ModelState> _states = widget.downloader.watch();

  @override
  void didUpdateWidget(_ModelStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloader != widget.downloader) {
      _states = widget.downloader.watch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.downloader;
    return StreamBuilder<ModelState>(
      stream: _states,
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
