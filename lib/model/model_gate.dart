import 'dart:async';
import 'dart:collection';

/// Accès exclusif au modèle local (ADR-005, proposé) : l'étiquetage (spec 004) et
/// le bilan (spec 006) le partagent, et le moteur ne doit jamais exécuter deux
/// générations à la fois, ni garder deux modèles en mémoire. Les demandes sont
/// servies dans l'ordre d'arrivée.
class ModelGate {
  bool _held = false;
  final _waiting = Queue<Completer<void>>();

  /// Vrai si une demande détient l'accès.
  bool get isHeld => _held;

  /// Attend l'accès et rend la fonction qui le libère (à appeler une seule fois).
  /// Rend `null`, sans jamais obtenir l'accès, si [abandon] se termine avant.
  Future<void Function()?> acquire({Future<void>? abandon}) async {
    if (!_held) {
      _held = true;
      return _releaser();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    var abandoned = false;
    abandon?.then((_) {
      if (turn.isCompleted) return;
      abandoned = true;
      _waiting.remove(turn);
      turn.complete();
    });
    await turn.future;
    // L'accès a été transmis à cette demande par [_releaser], sauf abandon.
    return abandoned ? null : _releaser();
  }

  void Function() _releaser() {
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_waiting.isEmpty) {
        _held = false;
      } else {
        // L'accès passe directement à la demande suivante : personne ne peut
        // le prendre entre-temps.
        _waiting.removeFirst().complete();
      }
    };
  }
}
