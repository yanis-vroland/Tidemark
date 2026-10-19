// Spec 007, CA6 : les jetons de marque sont identiques en clair et en sombre
// (une marque ne change pas de couleur avec le thème). La fidélité aux valeurs de
// tokens.json est vérifiée par charter_fidelity_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

void main() {
  test('CA6 : brand est identique en clair et en sombre', () {
    expect(TidemarkColors.light.brand, TidemarkColors.dark.brand);
  });

  test('CA6 : onBrand est identique en clair et en sombre', () {
    expect(TidemarkColors.light.onBrand, TidemarkColors.dark.onBrand);
  });

  test('CA6 : brandAccent est identique en clair et en sombre', () {
    expect(TidemarkColors.light.brandAccent, TidemarkColors.dark.brandAccent);
  });
}
