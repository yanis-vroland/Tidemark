import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';

/// Bouton destructeur (spec 005, CA35) : texte et bordure `danger` sur fond
/// `surface-raised`, jamais un fond `danger` plein (la charte n'a pas de jeton
/// `on-danger`) ; désactivé, il reprend le bouton désactivé de la maquette 001
/// (`line`, `surface-raised`, `ink-muted`).
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.announce = false,
  });

  /// Libellé annoncé dès qu'il change (état occupé, CA33).
  final bool announce;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _OutlinedAction(
    label: label,
    onPressed: onPressed,
    icon: icon,
    color: context.colors.danger,
    announce: announce,
  );
}

/// Bouton secondaire de la maquette 005 (« Exporter mes données ») : texte `tide`,
/// bordure `line`, fond `surface-raised`.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.announce = false,
  });

  /// Libellé annoncé dès qu'il change (état occupé, CA33).
  final bool announce;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _OutlinedAction(
    label: label,
    onPressed: onPressed,
    icon: icon,
    color: context.colors.tide,
    border: context.colors.line,
    announce: announce,
  );
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.color,
    this.border,
    this.announce = false,
  });

  final bool announce;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  /// Bordure du bouton actif ; par défaut, la couleur du texte.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? colors.inkMuted : color,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? colors.inkMuted : color,
      ),
      backgroundColor: WidgetStatePropertyAll(colors.surfaceRaised),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? colors.line
              : border ?? color,
        ),
      ),
    );
    // Libellé sur plusieurs lignes à 200 % plutôt que tronqué (CA34).
    // Annotation fusionnée dans le nœud du bouton : c'est lui qui est annoncé.
    final text = Semantics(
      liveRegion: announce,
      child: Text(label, textAlign: TextAlign.center),
    );
    final glyph = icon;
    return glyph == null
        ? OutlinedButton(style: style, onPressed: onPressed, child: text)
        : OutlinedButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(glyph, size: TidemarkSize.iconButton),
            label: text,
          );
  }
}
