import 'package:flutter/material.dart';

import '../../distress/distress_detector.dart';
import '../../model/model_downloader.dart';
import '../../settings/settings_repository.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/error_banner.dart';
import '../widgets/model_settings_section.dart';
import '../widgets/my_data_section.dart';

/// Écran des réglages (glossaire : `SettingsScreen`, spec 002). Un degré choisi est
/// enregistré aussitôt, sans bouton « Enregistrer » (CA19).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.downloader,
    this.data,
  });

  final SettingsRepository settings;

  /// Export et suppression totale : section « Mes données » (spec 005) ; `null` :
  /// section absente (écran testé seul).
  final DataActions? data;

  /// Modèle local : section « Analyse sur le téléphone » (spec 003).
  final ModelDownloader downloader;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// Nom et description de chaque degré (maquette, Reglages.dc.html).
const _degrees = {
  LowMoodSensitivity.high: (
    'Haute',
    '2 entrées « Très bas » d’affilée, en 3 jours au plus',
  ),
  LowMoodSensitivity.normal: (
    'Normale (recommandée)',
    '3 entrées « Très bas » d’affilée, en 7 jours au plus',
  ),
  LowMoodSensitivity.low: (
    'Basse',
    '5 entrées « Très bas » d’affilée, en 14 jours au plus',
  ),
};

class _SettingsScreenState extends State<SettingsScreen> {
  late final Stream<LowMoodSensitivity> _sensitivity = widget.settings
      .watchLowMoodSensitivity();
  bool _failed = false;

  /// Dernier degré enregistré avec succès : affiché si la lecture est en échec,
  /// pour que l'écran ne contredise pas le degré appliqué.
  LowMoodSensitivity? _saved;

  Future<void> _choose(LowMoodSensitivity? value) async {
    if (value == null) return;
    try {
      await widget.settings.setLowMoodSensitivity(value);
      if (mounted) {
        setState(() {
          _failed = false;
          _saved = value;
        });
      }
    } catch (_) {
      // Le degré coché vient de la base : le précédent reste coché (CA20).
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<LowMoodSensitivity>(
          stream: _sensitivity,
          builder: (context, snapshot) {
            // Lecture impossible : le degré appliqué est « Normale » (CA21).
            final current = snapshot.hasError
                ? _saved ?? LowMoodSensitivity.normal
                : snapshot.data;
            // Tout l'écran est construit : à 200 %, le bandeau d'erreur reste dans
            // l'arbre même après avoir défilé jusqu'aux degrés (CA25).
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: TidemarkSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.chevron_left,
                        size: TidemarkSize.iconMd,
                      ),
                      label: const Text('Journal'),
                    ),
                  ),
                  const SizedBox(height: TidemarkSpacing.space2),
                  Semantics(
                    header: true,
                    child: Text(
                      'Réglages',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: TidemarkSpacing.space4),
                    const ErrorBanner(
                      title: "Le réglage n'a pas été enregistré",
                      message: 'Le réglage précédent reste en place. Réessaie.',
                    ),
                  ],
                  // Après la lecture du degré : pendant le chargement, seuls le
                  // retour et le titre sont visibles (spec 002, CA22).
                  if (current != null) ...[
                    const SizedBox(height: TidemarkSpacing.space6),
                    ModelSettingsSection(downloader: widget.downloader),
                    const SizedBox(height: TidemarkSpacing.space6),
                    _HelpSection(current: current, onChanged: _choose),
                    if (widget.data case final data?) ...[
                      const SizedBox(height: TidemarkSpacing.space4),
                      MyDataSection(actions: data),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.current, required this.onChanged});

  final LowMoodSensitivity current;
  final ValueChanged<LowMoodSensitivity?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            "Écran d'aide",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: TidemarkSpacing.space3),
        Text(
          "L'écran d'aide s'ouvre quand tes dernières humeurs sont toutes "
          '« Très bas ». Choisis à partir de quand.',
          style: TidemarkTypography.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: TidemarkSpacing.space3),
        RadioGroup<LowMoodSensitivity>(
          groupValue: current,
          onChanged: onChanged,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final MapEntry(key: value, value: (name, detail))
                  in _degrees.entries) ...[
                _DegreeTile(
                  value: value,
                  name: name,
                  detail: detail,
                  selected: value == current,
                ),
                const SizedBox(height: TidemarkSpacing.space2),
              ],
            ],
          ),
        ),
        const SizedBox(height: TidemarkSpacing.space1),
        Text(
          "L'écran d'aide ne peut pas être désactivé. Les mots qui signalent un "
          "danger ouvrent toujours l'écran d'aide, quel que soit ce choix.",
          style: TidemarkTypography.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: TidemarkSpacing.space4),
      ],
    );
  }
}

/// Un degré : carte `surface-raised`, ou `tide-soft` bordée de `tide` s'il est choisi.
class _DegreeTile extends StatelessWidget {
  const _DegreeTile({
    required this.value,
    required this.name,
    required this.detail,
    required this.selected,
  });

  final LowMoodSensitivity value;
  final String name;
  final String detail;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Une seule annonce par degré, portée par un seul nœud : nom, description et
    // état coché (CA24).
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '$name\n$detail',
      onTap: () =>
          RadioGroup.maybeOf<LowMoodSensitivity>(context)?.onChanged(value),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.tideSoft : colors.surfaceRaised,
          borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
          border: selected
              ? Border.all(color: colors.tide, width: TidemarkSize.ringWidth)
              : Border.all(color: colors.line),
        ),
        // Matériau transparent : l'effet du toucher se peint au-dessus du fond.
        child: Material(
          type: MaterialType.transparency,
          child: RadioListTile<LowMoodSensitivity>(
            value: value,
            activeColor: colors.tide,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: TidemarkSpacing.space2,
              vertical: TidemarkSpacing.space2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
            ),
            title: Text(
              name,
              style: TidemarkTypography.headline.copyWith(color: colors.ink),
            ),
            subtitle: Text(
              detail,
              style: TidemarkTypography.body.copyWith(color: colors.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}
