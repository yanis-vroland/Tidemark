import 'dart:async';

/// Accès exclusif au modèle local (ADR-005, proposé) : l'étiquetage (spec 004) et
/// le bilan (spec 006) le partagent, et le moteur ne doit jamais exécuter deux
/// générations à la fois, ni garder deux modèles en mémoire. Les demandes sont
/// servies dans l'ordre d'arrivée.
class ModelGate {
  /// Vrai si une demande détient l'accès.
  bool get isHeld => throw UnimplementedError();

  /// Attend l'accès et rend la fonction qui le libère (à appeler une seule fois).
  /// Rend `null`, sans jamais obtenir l'accès, si [abandon] se termine avant.
  Future<void Function()?> acquire({Future<void>? abandon}) =>
      throw UnimplementedError();
}
