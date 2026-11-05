import 'package:flutter/widgets.dart';

/// Autorise les animations d'ambiance (bulles, vagues) sous lui (spec 008,
/// « Mouvement »).
///
/// Seul `main` l'active : sans lui, tout est dessiné immobile, ce qui garde les
/// tests déterministes. Même activé, le réglage « Réduire les animations » du
/// téléphone l'emporte (RM66).
class AmbientMotion extends InheritedWidget {
  const AmbientMotion({super.key, required this.enabled, required super.child});

  final bool enabled;

  /// Vrai si les animations d'ambiance doivent tourner à cet endroit.
  static bool of(BuildContext context) {
    final motion = context.dependOnInheritedWidgetOfExactType<AmbientMotion>();
    return (motion?.enabled ?? false) &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  bool updateShouldNotify(AmbientMotion oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Contrôleur d'une animation d'ambiance en boucle : créé quand
/// [AmbientMotion.of] est vrai, libéré sinon. À appeler depuis
/// `didChangeDependencies` ; rend le contrôleur, ou `null` au repos.
///
/// [initialValue], de 0 à 1, décale le départ du cycle : deux éléments animés
/// côte à côte ne bougent pas à l'unisson.
AnimationController? syncAmbientController({
  required BuildContext context,
  required TickerProvider vsync,
  required AnimationController? current,
  required Duration period,
  bool reverse = false,
  double initialValue = 0,
}) {
  final on = AmbientMotion.of(context);
  if (on && current == null) {
    return AnimationController(
      vsync: vsync,
      duration: period,
      value: initialValue,
    )..repeat(reverse: reverse);
  }
  if (!on && current != null) {
    current.dispose();
    return null;
  }
  return current;
}
