// Fermeture de la base par la suppression totale (spec 005, CA21 : « Réessayer »
// rejoue les étapes) : un second appel de `close` attend la même fermeture, mais
// une fermeture en échec peut être retentée. Revues IA et sécurité de la PR.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/storage/app_database.dart';

/// Fait échouer la première fermeture de la base, puis laisse passer les suivantes.
class FailingCloseOnce extends QueryInterceptor {
  int closeCalls = 0;

  @override
  Future<void> close(QueryExecutor inner) async {
    closeCalls++;
    if (closeCalls == 1) throw StateError('fermeture impossible');
    await inner.close();
  }
}

void main() {
  test('CA21 : une fermeture en échec est retentée au second appel', () async {
    final interceptor = FailingCloseOnce();
    final db = AppDatabase.withExecutor(
      NativeDatabase.memory().interceptWith(interceptor),
    );
    await db.countEntries();

    await expectLater(db.close(), throwsStateError);
    await db.close();

    expect(interceptor.closeCalls, 2);
  });

  test('deux fermetures réussies : la seconde attend la première, sans '
      'refermer', () async {
    final interceptor = FailingCloseOnce()..closeCalls = 1;
    final db = AppDatabase.withExecutor(
      NativeDatabase.memory().interceptWith(interceptor),
    );
    await db.countEntries();

    await Future.wait([db.close(), db.close()]);
    await db.close();

    expect(interceptor.closeCalls, 2);
  });
}
