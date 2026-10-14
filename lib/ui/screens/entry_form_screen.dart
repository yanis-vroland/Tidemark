import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/mood_dot.dart';

/// Seuil d'affichage du compteur de caractères (CA12).
const _counterThreshold = 1800;

/// « 1 850 » : milliers séparés par une espace.
String _thousands(int value) {
  final digits = '$value';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Saisie d'une entrée (spec 001). Se ferme après l'enregistrement ou l'abandon.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, required this.repository, this.clock});

  final EntryRepository repository;

  /// Date et heure locales affichées en tête ; [DateTime.now] par défaut.
  final DateTime Function()? clock;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _text = TextEditingController();
  int? _mood;
  bool _saving = false;
  bool _failed = false;

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

  bool get _hasText => _text.text.trim().isNotEmpty;

  Future<void> _save() async {
    final mood = _mood;
    if (mood == null || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.repository.addEntry(mood: mood, text: _text.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (!_hasText) {
      Navigator.of(context).pop();
      return;
    }
    final abandon = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner cette entrée ?'),
        content: const Text('Ce que tu as écrit ne sera pas enregistré.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (abandon == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = (widget.clock ?? DateTime.now)();
    final length = _text.text.runes.length;
    return PopScope(
      canPop: !_hasText,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
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
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : _cancel,
                            child: const Text('Annuler'),
                          ),
                          Text(
                            '${weekdayAndDate(now)} · ${timeLabel(now)}',
                            style: TidemarkTypography.caption.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: TidemarkSpacing.space4),
                      Text(
                        'Comment ça va ?',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      if (_failed) ...[
                        const SizedBox(height: TidemarkSpacing.space4),
                        const _ErrorBanner(),
                      ],
                      const SizedBox(height: TidemarkSpacing.space6),
                      Text(
                        'Ton humeur, de 1 à 5',
                        style: TidemarkTypography.label.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space3),
                      _MoodSelector(
                        selected: _mood,
                        onSelected: _saving
                            ? null
                            : (mood) => setState(() => _mood = mood),
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                      Row(
                        children: [
                          for (final (index, label) in const [
                            'Très bas',
                            'Très bien',
                          ].indexed)
                            Expanded(
                              child: Text(
                                label,
                                textAlign: index == 0
                                    ? TextAlign.start
                                    : TextAlign.end,
                                style: TidemarkTypography.caption.copyWith(
                                  color: colors.inkMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                      if (_mood != null)
                        Text(
                          moodLabel(_mood!),
                          style: TidemarkTypography.headline,
                        ),
                      const SizedBox(height: TidemarkSpacing.space6),
                      Text(
                        'Ce que tu veux en dire (facultatif)',
                        style: TidemarkTypography.label.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                      TextField(
                        controller: _text,
                        enabled: !_saving,
                        minLines: 5,
                        maxLines: null,
                        maxLength: maxTextLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                        style: TidemarkTypography.body.copyWith(
                          color: colors.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Une phrase suffit, ou rien du tout.',
                          hintMaxLines: 3,
                          filled: true,
                          fillColor: colors.surfaceRaised,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              TidemarkRadius.radiusSm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: colors.inkMuted,
                          ),
                          const SizedBox(width: TidemarkSpacing.space1),
                          Flexible(
                            child: Text(
                              "Chiffré et gardé sur ton téléphone. Rien n'est envoyé.",
                              style: TidemarkTypography.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  children: [
                    if (length >= _counterThreshold) ...[
                      Text(
                        '${_thousands(length)} / ${_thousands(maxTextLength)}',
                        style: TidemarkTypography.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                    ],
                    if (_mood == null) ...[
                      Text(
                        'Choisis une humeur pour enregistrer.',
                        textAlign: TextAlign.center,
                        style: TidemarkTypography.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space2),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: TidemarkTypography.label.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _mood == null || _saving ? null : _save,
                      child: Text(
                        _saving
                            ? 'Enregistrement…'
                            : _failed
                            ? 'Réessayer'
                            : 'Enregistrer',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'erreur (charte : `ErrorBanner`).
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.danger),
          borderRadius: BorderRadius.circular(TidemarkRadius.radiusSm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TidemarkSpacing.space4,
            vertical: TidemarkSpacing.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "L'entrée n'a pas été enregistrée",
                style: TidemarkTypography.headline.copyWith(
                  color: colors.danger,
                ),
              ),
              const SizedBox(height: TidemarkSpacing.space1),
              const Text(
                "Le stockage du téléphone est peut-être plein ou indisponible. "
                'Libère de la place, puis réessaie : ton texte est conservé.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur d'humeur (charte : `MoodSelector`).
class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var mood = 1; mood <= 5; mood++)
          Semantics(
            label: 'Humeur $mood sur 5 : ${moodLabel(mood)}',
            button: true,
            selected: selected == mood,
            excludeSemantics: true,
            onTap: onSelected == null ? null : () => onSelected!(mood),
            child: GestureDetector(
              onTap: onSelected == null ? null : () => onSelected!(mood),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected != null && selected != mood ? 0.55 : 1,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 3,
                      color: selected == mood
                          ? colors.tide
                          : colors.surface.withValues(alpha: 0),
                    ),
                  ),
                  child: MoodDot(mood: mood, size: TidemarkSize.moodDot),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
