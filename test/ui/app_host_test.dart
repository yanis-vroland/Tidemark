// Racine de l'app (spec 005, « Données » : AppHost) : remplace l'app affichée par
// celle que rend `restart`, sans redémarrer le processus (fin d'une suppression
// totale CA18, « Réessayer » au démarrage CA23).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/app_host.dart';

Widget text(String value) =>
    Directionality(textDirection: TextDirection.ltr, child: Text(value));

/// Un écran qui demande la réouverture de l'app quand on le touche.
Widget restartButton({required bool wiped}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Builder(
    builder: (context) => GestureDetector(
      onTap: () => AppHost.maybeOf(context)?.restart(wiped: wiped),
      child: const Text('ancienne app'),
    ),
  ),
);

void main() {
  testWidgets('CA18 : l\'hôte affiche d\'abord l\'app initiale', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppHost(
        initial: text('initiale'),
        restart: ({required wiped}) async => text('x'),
      ),
    );

    expect(find.text('initiale'), findsOneWidget);
  });

  testWidgets('CA18 : restart(wiped: true) remplace l\'app par celle que rend '
      'la fonction restart, avec wiped: true', (tester) async {
    final calls = <bool>[];
    await tester.pumpWidget(
      AppHost(
        initial: restartButton(wiped: true),
        restart: ({required wiped}) async {
          calls.add(wiped);
          return text('app rouverte');
        },
      ),
    );

    await tester.tap(find.text('ancienne app'));
    await tester.pump();
    await tester.pump();

    expect(calls, [true]);
    expect(find.text('app rouverte'), findsOneWidget);
    expect(find.text('ancienne app'), findsNothing);
  });

  testWidgets('CA23 : restart sans wiped rouvre avec wiped: false', (
    tester,
  ) async {
    final calls = <bool>[];
    await tester.pumpWidget(
      AppHost(
        initial: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () => AppHost.maybeOf(context)?.restart(),
              child: const Text('ancienne app'),
            ),
          ),
        ),
        restart: ({required wiped}) async {
          calls.add(wiped);
          return text('app rouverte');
        },
      ),
    );

    await tester.tap(find.text('ancienne app'));
    await tester.pump();
    await tester.pump();

    expect(calls, [false]);
    expect(find.text('app rouverte'), findsOneWidget);
  });

  testWidgets('CA18 : sans hôte, maybeOf rend null (écran testé seul)', (
    tester,
  ) async {
    var looked = false;
    AppHostState? found;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            looked = true;
            found = AppHost.maybeOf(context);
            return const Text('seul');
          },
        ),
      ),
    );

    expect(looked, isTrue);
    expect(found, isNull);
  });
}
