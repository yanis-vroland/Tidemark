import 'package:flutter/material.dart';

import '../../entries/topic.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import 'sticker.dart';

/// Titre des sections de sujets, à la saisie et au détail (spec 010).
const topicsTitle = 'Ce qui a compté';

/// Titre d'une section de sujets : en-tête pour le lecteur d'écran (CA3, CA7).
class _TopicsTitle extends StatelessWidget {
  const _TopicsTitle();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(topicsTitle, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// Section « Ce qui a compté » de la saisie (spec 010, CA1 à CA3) : les six sujets,
/// dans l'ordre de la liste, en autocollants à bascule. Un sujet choisi a le fond
/// `ink` et le texte `surface` ; les autres, le fond `surface-raised`.
class TopicToggles extends StatelessWidget {
  const TopicToggles({
    super.key,
    required this.selected,
    required this.onToggled,
  });

  final Set<Topic> selected;

  /// Appelé au toucher d'un sujet ; `null` pendant l'enregistrement.
  final ValueChanged<Topic>? onToggled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TopicsTitle(),
        const SizedBox(height: TidemarkSpacing.space3),
        // Le groupe des bascules porte le titre de la section (CA3) : le
        // lecteur d'écran l'annonce en y entrant.
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: topicsTitle,
          child: Wrap(
            spacing: TidemarkSpacing.space2,
            runSpacing: TidemarkSpacing.space2,
            children: [
              for (final topic in Topic.values)
                _TopicToggle(
                  topic: topic,
                  on: selected.contains(topic),
                  onTap: onToggled == null ? null : () => onToggled!(topic),
                  colors: colors,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicToggle extends StatelessWidget {
  const _TopicToggle({
    required this.topic,
    required this.on,
    required this.onTap,
    required this.colors,
  });

  final Topic topic;
  final bool on;
  final VoidCallback? onTap;
  final TidemarkColors colors;

  @override
  Widget build(BuildContext context) => Semantics(
    // Bouton à bascule : libellé du sujet et état choisi ou non (CA3).
    button: true,
    toggled: on,
    enabled: onTap != null,
    label: topic.label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        // Cible tactile minimale, quelle que soit la taille du texte.
        constraints: const BoxConstraints(
          minHeight: TidemarkSize.tapMin,
          minWidth: TidemarkSize.tapMin,
        ),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: Sticker(
            text: topic.label,
            background: on ? colors.ink : colors.surfaceRaised,
            foreground: on ? colors.surface : colors.ink,
          ),
        ),
      ),
    ),
  );
}

/// Section « Ce qui a compté » du détail (spec 010, CA7) : les sujets de l'entrée en
/// autocollants `ink` et `surface`. Rien sans sujet.
class EntryTopicsSection extends StatelessWidget {
  const EntryTopicsSection({super.key, required this.topics});

  final List<Topic> topics;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TidemarkSpacing.space6),
        const Align(alignment: Alignment.centerLeft, child: _TopicsTitle()),
        const SizedBox(height: TidemarkSpacing.space3),
        Wrap(
          spacing: TidemarkSpacing.space2,
          runSpacing: TidemarkSpacing.space2,
          children: [
            for (final topic in topicsInListOrder(topics))
              Sticker(
                text: topic.label,
                background: colors.ink,
                foreground: colors.surface,
              ),
          ],
        ),
      ],
    );
  }
}
