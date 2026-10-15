import 'package:flutter/material.dart';

import '../../model/model_downloader.dart';
import '../../model/model_source.dart';
import '../../model/model_state.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/error_banner.dart';
import '../widgets/model_progress_bar.dart';

/// Écran du modèle (spec 003) : proposition, progression, vérification, échec, prêt.
/// L'état vient du téléchargeur : un échec récent s'affiche dès l'ouverture (CA19).
class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key, required this.downloader});

  final ModelDownloader downloader;

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  late final Stream<ModelState> _states = widget.downloader.watch();

  /// Taille annoncée, calculée depuis `ModelSource` (CA4).
  final String _size = formatGigabytes(qwenModelSource.sizeBytes);

  void _start() {
    widget.downloader.start();
  }

  void _close() => Navigator.of(context).maybePop();

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le téléchargement ?'),
        content: const Text('Ce qui a déjà été téléchargé sera effacé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler le téléchargement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.downloader.cancel();
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ModelState>(
          stream: _states,
          initialData: widget.downloader.current,
          builder: (context, snapshot) {
            final state = snapshot.data ?? const ModelAbsent();
            return switch (state) {
              ModelAbsent(:final failure?) => _Failed(
                failure: failure,
                size: _size,
                onRetry: _start,
                onLater: _close,
              ),
              ModelAbsent() => _Offer(
                size: _size,
                onDownload: _start,
                onLater: _close,
              ),
              ModelDownloading() => _Transfer(
                state: state,
                size: _size,
                onCancel: _confirmCancel,
                onBack: _close,
              ),
              ModelReady() => _Ready(onBack: _close),
            };
          },
        ),
      ),
    );
  }
}

/// Mise en page commune : contenu qui défile, boutons fixés en bas, toujours
/// visibles (CA29).
class _Layout extends StatelessWidget {
  const _Layout({required this.body, required this.actions});

  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: TidemarkSpacing.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TidemarkSpacing.space8),
              ...body,
              const SizedBox(height: TidemarkSpacing.space4),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          TidemarkSpacing.space4,
          TidemarkSpacing.space3,
          TidemarkSpacing.space4,
          TidemarkSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions,
        ),
      ),
    ],
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.status = false});

  final String text;
  final bool status;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    liveRegion: status,
    child: Text(text, style: Theme.of(context).textTheme.displaySmall),
  );
}

class _Offer extends StatelessWidget {
  const _Offer({
    required this.size,
    required this.onDownload,
    required this.onLater,
  });

  final String size;
  final VoidCallback onDownload;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TidemarkTypography.body.copyWith(color: colors.inkMuted);
    Widget point(IconData icon, String title, String detail) => Padding(
      padding: const EdgeInsets.only(bottom: TidemarkSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: TidemarkSize.iconMd, color: colors.tide),
          const SizedBox(width: TidemarkSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TidemarkTypography.headline),
                Text(detail, style: muted),
              ],
            ),
          ),
        ],
      ),
    );
    return _Layout(
      body: [
        const _Title('Des étiquettes pour ton journal'),
        const SizedBox(height: TidemarkSpacing.space3),
        const Text(
          'Tidemark peut proposer des émotions et des thèmes pour chaque entrée. '
          "L'analyse se fait sur ton téléphone, par un modèle à télécharger une "
          'seule fois.',
        ),
        const SizedBox(height: TidemarkSpacing.space6),
        point(
          Icons.download_outlined,
          '$size, une seule fois',
          'Le modèle reste ensuite sur ton téléphone.',
        ),
        point(
          Icons.lock_outline,
          "Rien de ton journal n'est envoyé",
          'Le téléchargement ne transmet aucune de tes entrées.',
        ),
        point(
          Icons.wifi_off_outlined,
          'Ensuite, tout se fait sans réseau',
          'Tes entrées sont analysées sur ton téléphone.',
        ),
        const SizedBox(height: TidemarkSpacing.space2),
        Text(
          'Préfère le Wi-Fi : sur données mobiles, $size compte dans ton '
          'forfait. Garde Tidemark ouvert pendant le téléchargement.',
          style: TidemarkTypography.caption.copyWith(color: colors.inkMuted),
        ),
      ],
      actions: [
        FilledButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download, size: TidemarkSize.iconButton),
          label: Text('Télécharger le modèle ($size)'),
        ),
        const SizedBox(height: TidemarkSpacing.space2),
        TextButton(onPressed: onLater, child: const Text('Plus tard')),
      ],
    );
  }
}

class _Transfer extends StatelessWidget {
  const _Transfer({
    required this.state,
    required this.size,
    required this.onCancel,
    required this.onBack,
  });

  final ModelDownloading state;
  final String size;
  final VoidCallback onCancel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final verifying = state.verifying;
    final percent = verifying
        ? 100
        : percentOf(state.receivedBytes, state.totalBytes);
    final received = verifying
        ? '$size sur $size'
        : '${formatMegabytes(state.receivedBytes)} sur $size';
    return _Layout(
      body: [
        const _Title('Téléchargement du modèle'),
        const SizedBox(height: TidemarkSpacing.space6),
        ExcludeSemantics(
          child: Text(
            '$percent %',
            style: TidemarkTypography.moodNumeral.copyWith(color: colors.tide),
          ),
        ),
        const SizedBox(height: TidemarkSpacing.space2),
        ModelProgressBar(percent: percent),
        const SizedBox(height: TidemarkSpacing.space2),
        Text(
          received,
          style: TidemarkTypography.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: TidemarkSpacing.space4),
        if (verifying)
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: TidemarkSize.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.tide,
                  ),
                ),
                const SizedBox(width: TidemarkSpacing.space2),
                const Expanded(child: Text('Vérification du fichier…')),
              ],
            ),
          )
        else
          Text(
            'Tu peux revenir à ton journal pendant ce temps. Garde Tidemark '
            "ouvert : si tu quittes l'app, le téléphone peut interrompre le "
            'téléchargement, qui repartirait de zéro.',
            style: TidemarkTypography.body.copyWith(color: colors.inkMuted),
          ),
      ],
      actions: [
        if (!verifying) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.surfaceRaised,
              side: BorderSide(color: colors.line),
            ),
            onPressed: onCancel,
            child: const Text('Annuler le téléchargement'),
          ),
          const SizedBox(height: TidemarkSpacing.space2),
        ],
        TextButton(
          onPressed: onBack,
          child: const Text('Revenir à mon journal'),
        ),
      ],
    );
  }
}

/// Textes du bandeau d'échec, par cause (maquette, CA15, CA17, CA18).
(String, String) _failureTexts(DownloadFailure failure, String size) =>
    switch (failure) {
      DownloadFailure.network => (
        "Le téléchargement s'est interrompu",
        "La connexion a été perdue ou le serveur n'a pas répondu. Vérifie ta "
            'connexion, puis réessaie.',
      ),
      DownloadFailure.checksum => (
        "Le fichier reçu n'est pas le bon",
        'Il ne correspond pas au modèle attendu et a été effacé. Réessaie.',
      ),
      DownloadFailure.storage => (
        'Pas assez de place sur le téléphone',
        'Le modèle demande $size libres. Libère de la place, puis réessaie.',
      ),
    };

class _Failed extends StatelessWidget {
  const _Failed({
    required this.failure,
    required this.size,
    required this.onRetry,
    required this.onLater,
  });

  final DownloadFailure failure;
  final String size;
  final VoidCallback onRetry;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final (title, message) = _failureTexts(failure, size);
    return _Layout(
      body: [
        const _Title('Téléchargement du modèle'),
        const SizedBox(height: TidemarkSpacing.space6),
        ErrorBanner(title: title, message: message),
        const SizedBox(height: TidemarkSpacing.space4),
        const Text(
          'Rien n\'a été gardé : le téléchargement repartira de zéro.',
        ),
      ],
      actions: [
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: TidemarkSize.iconButton),
          label: Text('Réessayer ($size)'),
        ),
        const SizedBox(height: TidemarkSpacing.space2),
        TextButton(onPressed: onLater, child: const Text('Plus tard')),
      ],
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Layout(
      body: [
        const _Title('Le modèle est prêt', status: true),
        const SizedBox(height: TidemarkSpacing.space3),
        const Text(
          'Tes entrées avec du texte vont être analysées sur ton téléphone, une à '
          'la fois. Leurs étiquettes apparaîtront dans ton journal.',
        ),
        const SizedBox(height: TidemarkSpacing.space4),
        Row(
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: TidemarkSize.iconSm,
              color: colors.inkMuted,
            ),
            const SizedBox(width: TidemarkSpacing.space2),
            Expanded(
              child: Text(
                "L'analyse fonctionne maintenant sans réseau.",
                style: TidemarkTypography.caption.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
      actions: [
        FilledButton(
          onPressed: onBack,
          child: const Text('Revenir à mon journal'),
        ),
      ],
    );
  }
}
