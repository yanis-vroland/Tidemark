import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../distress/guarded_save.dart';
import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../entries/topic.dart';
import '../../model/model_downloader.dart';
import '../../settings/settings_repository.dart';
import '../motion/ambient_motion.dart';
import '../phone_dialer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/air_bubbles.dart';
import '../widgets/error_banner.dart';
import '../widgets/dashed_circle.dart';
import '../widgets/entry_topics.dart';
import '../widgets/mood_bubble.dart';
import '../widgets/sticker.dart';
import 'celebration_screen.dart';
import 'help_screen.dart';

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

/// Saisie d'une entrée (spec 001). Remplacée par la célébration après un
/// enregistrement réussi (spec 010), fermée à l'abandon.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.downloader,
    this.dialer = const UrlLauncherDialer(),
    this.clock,
    this.initialMood,
  }) : assert(
         initialMood == null || (initialMood >= 1 && initialMood <= 5),
         'initialMood doit valoir de 1 à 5',
       );

  final EntryRepository repository;

  /// Humeur déjà choisie à l'ouverture (bulle du check-in, spec 009, CA13) ;
  /// `null` : aucune humeur choisie (spec 001, CA7).
  final int? initialMood;

  /// Degré de sensibilité aux humeurs basses (spec 002).
  final SettingsRepository settings;

  /// Modèle local : proposition après la première entrée « en attente » (spec 003),
  /// ouverte par la célébration (spec 010, CA16).
  final ModelDownloader downloader;

  /// Composeur, pour l'écran d'aide (spec 002).
  final PhoneDialer dialer;

  /// Date et heure locales affichées en tête ; [DateTime.now] par défaut.
  final DateTime Function()? clock;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  late int? _mood = widget.initialMood;

  /// Sujets choisis (spec 010) : gardés après une erreur, repris par « Réessayer ».
  final _topics = <Topic>{};
  bool _saving = false;
  bool _failed = false;

  /// Bulles d'air qui montent, en ambiance seulement (spec 008, « Mouvement »).
  AnimationController? _air;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _air = syncAmbientController(
      context: context,
      vsync: this,
      current: _air,
      period: entryAirPeriod,
    );
  }

  @override
  void dispose() {
    _air?.dispose();
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
      final outcome = await saveEntryWithGuard(
        repository: widget.repository,
        settings: widget.settings,
        mood: mood,
        // Sans texte saisi, l'entrée n'a pas de texte (spec 001, RM13).
        text: _hasText ? _text.text : null,
        topics: topicsInListOrder(_topics),
        clock: widget.clock ?? DateTime.now,
      );
      if (!mounted) return;
      if (outcome.showHelp) {
        // L'écran d'aide prend la place de la saisie : le retour mène à la liste
        // (spec 002, CA13).
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => HelpScreen(dialer: widget.dialer),
          ),
        );
      } else {
        // La célébration prend la place de la saisie ; c'est elle qui ouvre la
        // proposition du modèle, ou ramène à l'accueil (spec 010, CA12, CA16).
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => CelebrationScreen(
              entry: outcome.entry,
              repository: widget.repository,
              settings: widget.settings,
              downloader: widget.downloader,
            ),
          ),
        );
      }
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
    final length = _text.text.characters.length;
    return PopScope(
      // Pendant l'enregistrement, aucun retour : la fermeture viendra de _save.
      canPop: !_hasText && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _cancel();
      },
      child: Scaffold(
        // Le fond prend la teinte de l'humeur choisie (spec 008, CA11).
        backgroundColor: _mood == null
            ? colors.surface
            : colors.moodNightColor(_mood!),
        body: Stack(
          children: [
            // Décor sous le contenu : jamais annoncé ni touchable, absent
            // sans ambiance ou sous « réduire les animations ». Toujours un
            // enfant à cette place : le contenu garde son état (focus du texte)
            // quand l'ambiance change.
            Positioned.fill(
              child: _air == null
                  ? const SizedBox.shrink()
                  : AirBubbles(animation: _air!),
            ),
            SafeArea(
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
                            const ErrorBanner(
                              title: "L'entrée n'a pas été enregistrée",
                              message:
                                  'Le stockage du téléphone est peut-être plein ou '
                                  'indisponible. Libère de la place, puis réessaie : '
                                  'ton texte est conservé.',
                            ),
                          ],
                          const SizedBox(height: TidemarkSpacing.space4),
                          Center(
                            child: _mood == null
                                ? const _MoodPlaceholder()
                                : MoodBubble(
                                    mood: _mood!,
                                    size: TidemarkSize.bubbleXl,
                                  ),
                          ),
                          const SizedBox(height: TidemarkSpacing.space4),
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
                              for (final (index, label) in [
                                moodLabels.first,
                                moodLabels.last,
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
                          // Ce qui a compté, choisi en un geste (spec 010, CA1 à CA3).
                          TopicToggles(
                            selected: _topics,
                            onToggled: _saving
                                ? null
                                : (topic) => setState(() {
                                    if (!_topics.remove(topic)) {
                                      _topics.add(topic);
                                    }
                                  }),
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
                            // Le clavier n'apprend pas les mots du journal (RM1).
                            enableIMEPersonalizedLearning: false,
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
                              hintMaxLines: 5,
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
                                size: TidemarkSize.iconSm,
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
                        PressShadow(
                          child: FilledButton(
                            onPressed: _mood == null || _saving ? null : _save,
                            child: Text(
                              _saving
                                  ? 'Enregistrement…'
                                  : _failed
                                  ? 'Réessayer'
                                  : 'Enregistrer',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur d'humeur (charte v2 : cinq bulles de marée, spec 008, CA11).
class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
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
              behavior: HitTestBehavior.opaque,
              onTap: onSelected == null ? null : () => onSelected!(mood),
              child: SizedBox.square(
                // Cible tactile constante, quelle que soit la taille de la bulle.
                dimension: TidemarkSize.bubbleSelectOn,
                child: Center(
                  child: MoodBubble(
                    mood: mood,
                    size: selected == mood
                        ? TidemarkSize.bubbleSelectOn
                        : TidemarkSize.bubbleSelect,
                    ring: selected == mood,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cercle pointillé `line` à la place de la grande bulle, tant qu'aucune humeur
/// n'est choisie (spec 008, CA11).
class _MoodPlaceholder extends StatelessWidget {
  const _MoodPlaceholder();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      key: const Key('mood-placeholder'),
      size: const Size.square(TidemarkSize.bubbleXl),
      painter: DashedCirclePainter(color: context.colors.line),
    ),
  );
}
