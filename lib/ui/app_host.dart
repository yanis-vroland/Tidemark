import 'package:flutter/widgets.dart';

/// Racine de l'app : affiche [initial], puis l'app rendue par [restart] quand un
/// écran le demande (fin d'une suppression totale, « Réessayer » au démarrage,
/// spec 005), sans redémarrer le processus.
class AppHost extends StatefulWidget {
  const AppHost({super.key, required this.initial, required this.restart});

  final Widget initial;

  /// Rouvre l'app (`startApp`) ; [wiped] : une suppression totale vient de réussir,
  /// la liste affiche le message de fin (CA18).
  final Future<Widget> Function({required bool wiped}) restart;

  /// Racine la plus proche, ou `null` (écran testé seul).
  static AppHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppHostState>();

  @override
  State<AppHost> createState() => AppHostState();
}

class AppHostState extends State<AppHost> {
  /// Remplace l'app affichée par celle que rend [AppHost.restart].
  Future<void> restart({bool wiped = false}) => throw UnimplementedError();

  @override
  Widget build(BuildContext context) => widget.initial;
}
