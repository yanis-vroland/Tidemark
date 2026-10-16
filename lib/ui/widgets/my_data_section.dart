import 'package:flutter/material.dart';

import '../../entries/entry.dart';
import '../../export/journal_export.dart';
import '../../wipe/journal_wiper.dart';
import '../screens/wipe_confirmation_screen.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'action_buttons.dart';
import 'error_banner.dart';

/// Ce que la section « Mes données » des Réglages déclenche (spec 005) : l'export
/// et la suppression totale.
class DataActions {
  const DataActions({required this.export, required this.wiper});

  final JournalExport export;
  final JournalWiper wiper;
}

/// Section « Mes données » des Réglages (spec 005, CA1 à CA14).
class MyDataSection extends StatefulWidget {
  const MyDataSection({super.key, required this.actions});

  final DataActions actions;

  @override
  State<MyDataSection> createState() => _MyDataSectionState();
}

class _MyDataSectionState extends State<MyDataSection> {
  late final Stream<List<Entry>> _entries = widget.actions.export.entries
      .watchEntries();
  bool _exporting = false;
  bool _failed = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.actions.export.run();
    } catch (_) {
      failed = true;
    }
    if (mounted) {
      setState(() {
        _exporting = false;
        _failed = failed;
      });
    }
  }

  void _openWipe() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WipeConfirmationScreen(wiper: widget.actions.wiper),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TidemarkTypography.body.copyWith(color: colors.inkMuted);
    final note = TidemarkTypography.caption.copyWith(color: colors.inkMuted);
    // Pendant l'export, aucun retour : la feuille de partage s'ouvre sur cet
    // écran (CA3).
    return PopScope(
      canPop: !_exporting,
      child: StreamBuilder<List<Entry>>(
        stream: _entries,
        builder: (context, snapshot) {
          // Tant que le nombre d'entrées est inconnu, ou illisible, l'export
          // n'est pas proposé.
          final count = snapshot.hasError ? null : snapshot.data?.length;
          final empty = count == 0;
          final canExport = !_exporting && count != null && count > 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Mes données',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: TidemarkSpacing.space3),
              Text(
                'Tout reste sur ce téléphone. Tu peux en faire une copie, ou '
                'tout effacer.',
                style: muted,
              ),
              if (_failed) ...[
                const SizedBox(height: TidemarkSpacing.space3),
                const ErrorBanner(
                  title: "L'export n'a pas abouti",
                  message:
                      "Aucun fichier n'a été partagé. Vérifie la place libre "
                      'sur le téléphone, puis réessaie.',
                ),
              ],
              const SizedBox(height: TidemarkSpacing.space3),
              // Annoncé dès qu'il devient « Préparation de l'export… » (CA33).
              QuietButton(
                announce: _exporting,
                icon: Icons.ios_share,
                label: _exporting
                    ? "Préparation de l'export…"
                    : _failed
                    ? "Réessayer l'export"
                    : 'Exporter mes données',
                onPressed: canExport ? _export : null,
              ),
              const SizedBox(height: TidemarkSpacing.space2),
              Text(
                empty
                    ? "Ton journal est vide : il n'y a rien à exporter."
                    : 'Un fichier JSON avec toutes tes entrées et leurs '
                          "étiquettes. Il n'est pas chiffré : choisis bien où tu "
                          "l'envoies.",
                style: note,
              ),
              const SizedBox(height: TidemarkSpacing.space6),
              DangerButton(
                icon: Icons.delete_outline,
                label: 'Tout supprimer',
                onPressed: _exporting ? null : _openWipe,
              ),
              const SizedBox(height: TidemarkSpacing.space2),
              Text(
                'Efface définitivement tes entrées, tes réglages, la clé de ton '
                "journal et le modèle d'IA téléchargé.",
                style: note,
              ),
              const SizedBox(height: TidemarkSpacing.space4),
            ],
          );
        },
      ),
    );
  }
}
