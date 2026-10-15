import 'package:flutter/widgets.dart';

import '../analysis/analysis_queue.dart';

/// Rend la file d'analyse visible des écrans (liste, détail), qui se reconstruisent
/// à chacun de ses changements (spec 004, CA20, CA22, CA31).
class AnalysisScope extends InheritedNotifier<AnalysisQueue> {
  const AnalysisScope({
    super.key,
    required AnalysisQueue queue,
    required super.child,
  }) : super(notifier: queue);

  /// File de l'app, ou `null` si aucune n'est fournie.
  static AnalysisQueue? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnalysisScope>()?.notifier;
}
