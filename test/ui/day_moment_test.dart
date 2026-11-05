// Moment de la journée (spec 009, définitions, CA7, CA10, CA11) : « jour » de 05:00 à
// 17:59, « soir » de 18:00 à 04:59, heure locale.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/day_moment.dart';

DateTime at(int hour, int minute) => DateTime(2026, 10, 14, hour, minute);

void main() {
  group('dayMomentOf', () {
    test('CA7 : 05:00 est le jour, 04:59 est encore le soir', () {
      expect(dayMomentOf(at(5, 0)), DayMoment.day);
      expect(dayMomentOf(at(4, 59)), DayMoment.evening);
    });

    test('CA7 : 17:59 est le jour, 18:00 est le soir', () {
      expect(dayMomentOf(at(17, 59)), DayMoment.day);
      expect(dayMomentOf(at(18, 0)), DayMoment.evening);
    });

    test('CA7 : minuit, midi et le milieu de la nuit', () {
      expect(dayMomentOf(at(0, 0)), DayMoment.evening);
      expect(dayMomentOf(at(12, 0)), DayMoment.day);
      expect(dayMomentOf(at(2, 30)), DayMoment.evening);
      expect(dayMomentOf(at(23, 59)), DayMoment.evening);
    });

    test('CA7 : chaque minute de la journée est rangée du bon côté', () {
      for (var minutes = 0; minutes < 24 * 60; minutes++) {
        final t = at(minutes ~/ 60, minutes % 60);
        final isDay = minutes >= 5 * 60 && minutes < 18 * 60;
        expect(
          dayMomentOf(t),
          isDay ? DayMoment.day : DayMoment.evening,
          reason: '${t.hour}:${t.minute}',
        );
      }
    });
  });

  group('textes', () {
    test('CA7 : « Bonjour » le jour, « Bonsoir » le soir', () {
      expect(greetingFor(DayMoment.day), 'Bonjour');
      expect(greetingFor(DayMoment.evening), 'Bonsoir');
    });

    test('CA11 : le titre du check-in suit le moment', () {
      expect(
        checkInTitleFor(DayMoment.day),
        "Comment va ta marée aujourd'hui ?",
      );
      expect(
        checkInTitleFor(DayMoment.evening),
        'Comment va ta marée ce soir ?',
      );
    });
  });
}
