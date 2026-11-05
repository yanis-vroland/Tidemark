import 'package:flutter/material.dart';

import '../phone_dialer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';

/// Écran d'aide fixe (glossaire : `HelpScreen`, spec 002, RM7) : textes écrits pour
/// le projet, jamais générés, sans rapport avec le contenu de l'entrée. Sans la
/// couleur `danger` (charte).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, required this.dialer});

  final PhoneDialer dialer;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool _callFailed = false;

  Future<void> _call(String number) async {
    bool opened;
    try {
      opened = await widget.dialer.dial(number);
    } catch (_) {
      opened = false;
    }
    if (mounted) setState(() => _callFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TidemarkTypography.body.copyWith(color: colors.inkMuted);
    return Scaffold(
      body: SafeArea(
        child: Column(
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
                    Semantics(
                      header: true,
                      child: Text(
                        'Parler peut aider',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space3),
                    const Text(
                      "Ton entrée est bien enregistrée. Si c'est difficile en ce "
                      'moment, des personnes formées peuvent t\'écouter, '
                      'gratuitement, à toute heure.',
                    ),
                    if (_callFailed) ...[
                      const SizedBox(height: TidemarkSpacing.space6),
                      const _CallFailedNote(),
                    ],
                    const SizedBox(height: TidemarkSpacing.space6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        borderRadius: BorderRadius.circular(
                          TidemarkRadius.radiusMd,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(TidemarkSpacing.space4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Lu chiffre par chiffre, pas « trois mille… » (CA23).
                            Semantics(
                              label: '3 1 1 4',
                              excludeSemantics: true,
                              child: Text(
                                '3114',
                                style: TidemarkTypography.display.copyWith(
                                  color: colors.tide,
                                ),
                              ),
                            ),
                            const SizedBox(height: TidemarkSpacing.space1),
                            Text(
                              'Numéro national de prévention du suicide',
                              style: TidemarkTypography.headline,
                            ),
                            Text(
                              'Gratuit, 24 h/24, 7 j/7',
                              style: TidemarkTypography.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: TidemarkSpacing.space4),
                            FilledButton.icon(
                              onPressed: () => _call('3114'),
                              icon: const Icon(
                                Icons.phone_outlined,
                                size: TidemarkSize.iconButton,
                              ),
                              label: const Text('Appeler le 3114'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space6),
                    Text(
                      'Danger immédiat ?',
                      style: TidemarkTypography.headline,
                    ),
                    const SizedBox(height: TidemarkSpacing.space1),
                    Text(
                      "Appelle le 112, le numéro d'urgence européen.",
                      style: muted,
                    ),
                    const SizedBox(height: TidemarkSpacing.space3),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colors.surfaceRaised,
                        side: BorderSide(color: colors.line),
                      ),
                      onPressed: () => _call('112'),
                      icon: const Icon(
                        Icons.phone_outlined,
                        size: TidemarkSize.iconButton,
                      ),
                      label: const Text('Appeler le 112'),
                    ),
                    const SizedBox(height: TidemarkSpacing.space4),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TidemarkSpacing.space4,
                0,
                TidemarkSpacing.space4,
                TidemarkSpacing.space4,
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Revenir à mon journal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mention « appel impossible » (CA12), sur `tide-soft` : jamais `danger` ici.
class _CallFailedNote extends StatelessWidget {
  const _CallFailedNote();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.tideSoft,
          borderRadius: BorderRadius.circular(TidemarkRadius.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TidemarkSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "L'appel n'a pas pu être lancé",
                style: TidemarkTypography.headline,
              ),
              const SizedBox(height: TidemarkSpacing.space1),
              const Text(
                'Compose le numéro depuis ton téléphone : 3114, ou 112 en cas '
                'de danger immédiat.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
