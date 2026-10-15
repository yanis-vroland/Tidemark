import '../model/model_gate.dart';
import 'review_writer.dart';
import 'weekly_review.dart';

/// [ReviewWriter] qui attend l'accès au modèle ([ModelGate]) avant chaque mise en
/// mots, et ne le rend qu'une fois le rédacteur revenu : jamais deux générations à
/// la fois (spec 006, « Modèle occupé par l'étiquetage », ADR-005).
class GatedReviewWriter implements ReviewWriter {
  GatedReviewWriter(this.inner, this.gate);

  final ReviewWriter inner;
  final ModelGate gate;

  /// Rend [WriterFailed] si [cancel] arrive avant l'accès.
  @override
  Future<ReviewDraft> write(ReviewFacts facts) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();
}
