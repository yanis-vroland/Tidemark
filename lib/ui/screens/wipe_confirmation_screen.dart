import 'package:flutter/material.dart';

import '../../wipe/journal_wiper.dart';
import '../app_host.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/action_buttons.dart';
import '../widgets/error_banner.dart';

/// Mot à écrire pour confirmer (RM42).
const wipeConfirmationWord = 'SUPPRIMER';

/// Vrai si [text] confirme la suppression : « SUPPRIMER », sans tenir compte de la
/// casse ni des espaces au début et à la fin (CA15).
bool confirmsWipe(String text) =>
    text.trim().toUpperCase() == wipeConfirmationWord;

/// Confirmation de la suppression totale (glossaire : `WipeConfirmationScreen`,
/// spec 005, CA14 à CA21, CA27) : la personne écrit « SUPPRIMER ».
class WipeConfirmationScreen extends StatefulWidget {
  const WipeConfirmationScreen({
    super.key,
    required this.wiper,
    this.keyMissing = false,
    this.onWiped,
  });

  final JournalWiper wiper;

  /// Ouverte depuis l'écran « clé introuvable » (CA27) : liste et avertissement
  /// adaptés, retour « Retour » au lieu de « Réglages ».
  final bool keyMissing;

  /// Appelé après une suppression réussie ; par défaut, l'app est rouverte par
  /// `AppHost` avec le message de fin (CA18).
  final Future<void> Function()? onWiped;

  @override
  State<WipeConfirmationScreen> createState() => _WipeConfirmationScreenState();
}

enum _Phase {
  /// En attente de la confirmation.
  idle,

  /// Suppression en cours.
  running,

  /// Le marqueur n'a pas pu être écrit : rien n'a été effacé (CA20).
  notStarted,

  /// Une étape a échoué : la suppression doit reprendre (CA21).
  incomplete,
}

class _WipeConfirmationScreenState extends State<WipeConfirmationScreen> {
  final _text = TextEditingController();
  _Phase _phase = _Phase.idle;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Annuler et revenir en arrière ne sont possibles que tant que rien n'a pu
  /// être effacé.
  bool get _canLeave => _phase == _Phase.idle || _phase == _Phase.notStarted;

  Future<void> _confirm() async {
    final resume = _phase == _Phase.incomplete;
    setState(() => _phase = _Phase.running);
    try {
      // Après un échec en cours de route, « Réessayer » reprend où la
      // suppression s'est arrêtée, sans réécrire le marqueur.
      if (resume) {
        await widget.wiper.resume();
      } else {
        await widget.wiper.wipe();
      }
    } on WipeNotStartedError {
      if (mounted) setState(() => _phase = _Phase.notStarted);
      return;
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.incomplete);
      return;
    }
    // L'écran reste sur « Suppression… » jusqu'à ce que l'app rouverte le
    // remplace par la liste vide.
    final onWiped = widget.onWiped;
    if (onWiped != null) {
      await onWiped();
    } else if (mounted) {
      await AppHost.maybeOf(context)?.restart(wiped: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = TidemarkTypography.body.copyWith(color: colors.ink);
    final running = _phase == _Phase.running;
    final retry = _phase == _Phase.incomplete || _phase == _Phase.notStarted;
    final enabled = switch (_phase) {
      _Phase.idle || _Phase.notStarted => confirmsWipe(_text.text),
      _Phase.incomplete => true,
      _Phase.running => false,
    };
    final items = widget.keyMissing
        ? const [
            'tes entrées et leurs étiquettes, illisibles sans leur clé ;',
            'tes réglages ;',
            "le modèle d'IA téléchargé.",
          ]
        : const [
            'toutes tes entrées et leurs étiquettes ;',
            'tes réglages ;',
            'la clé qui protège ton journal ;',
            "le modèle d'IA téléchargé.",
          ];
    return PopScope(
      canPop: _canLeave,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TidemarkSpacing.space4,
                ),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_canLeave)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              size: TidemarkSize.iconMd,
                            ),
                            label: Text(
                              widget.keyMissing ? 'Retour' : 'Réglages',
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: TidemarkSize.tapMin),
                      const SizedBox(height: TidemarkSpacing.space2),
                      Semantics(
                        header: true,
                        child: Text(
                          'Tout supprimer ?',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      if (_phase == _Phase.incomplete) ...[
                        const SizedBox(height: TidemarkSpacing.space4),
                        const ErrorBanner(
                          title: "La suppression n'est pas terminée",
                          message: wipeIncompleteMessage,
                        ),
                      ],
                      if (_phase == _Phase.notStarted) ...[
                        const SizedBox(height: TidemarkSpacing.space4),
                        const ErrorBanner(
                          title: "La suppression n'a pas commencé",
                          message: "Rien n'a été effacé. Réessaie.",
                        ),
                      ],
                      const SizedBox(height: TidemarkSpacing.space4),
                      Text(
                        'Cette action efface définitivement, sur ce '
                        'téléphone :',
                        style: body,
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: TidemarkSpacing.space2,
                            bottom: TidemarkSpacing.space1,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(child: Text('•  ', style: body)),
                              Expanded(child: Text(item, style: body)),
                            ],
                          ),
                        ),
                      const SizedBox(height: TidemarkSpacing.space1),
                      Text(
                        widget.keyMissing
                            ? 'Rien ne pourra être récupéré. Sans sa clé, ton '
                                  'journal ne peut pas être exporté.'
                            : 'Rien ne pourra être récupéré. Pour garder une '
                                  "copie, exporte d'abord tes données depuis "
                                  'les Réglages.',
                        style: TidemarkTypography.body.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space6),
                      _ConfirmationField(
                        controller: _text,
                        enabled:
                            _phase == _Phase.idle ||
                            _phase == _Phase.notStarted,
                      ),
                      const Spacer(),
                      const SizedBox(height: TidemarkSpacing.space6),
                      if (running) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            "Si l'app se ferme, la suppression reprendra au "
                            'prochain lancement.',
                            style: TidemarkTypography.caption.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: TidemarkSpacing.space3),
                      ],
                      DangerButton(
                        announce: running,
                        label: running
                            ? 'Suppression…'
                            : retry
                            ? 'Réessayer'
                            : 'Tout supprimer définitivement',
                        onPressed: enabled ? _confirm : null,
                      ),
                      if (_canLeave) ...[
                        const SizedBox(height: TidemarkSpacing.space2),
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Annuler'),
                        ),
                      ],
                      const SizedBox(height: TidemarkSpacing.space4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texte du bandeau « La suppression n'est pas terminée » (CA21, CA23).
const wipeIncompleteMessage =
    'Une partie de tes données a peut-être déjà été effacée. Réessaie : la '
    "suppression reprend où elle s'est arrêtée.";

/// Champ de confirmation : clavier en majuscules, sans correction ni
/// apprentissage du clavier (CA15).
class _ConfirmationField extends StatelessWidget {
  const _ConfirmationField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Libellé visible fusionné dans le nœud du champ : le lecteur d'écran
    // l'annonce « Pour confirmer, écris SUPPRIMER » (CA33).
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pour confirmer, écris $wipeConfirmationWord',
            style: TidemarkTypography.headline.copyWith(color: colors.ink),
          ),
          const SizedBox(height: TidemarkSpacing.space2),
          TextField(
            controller: controller,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            style: TidemarkTypography.body.copyWith(color: colors.ink),
            decoration: InputDecoration(
              hintText: wipeConfirmationWord,
              filled: true,
              fillColor: colors.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TidemarkRadius.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
