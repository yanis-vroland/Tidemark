/// Moment de la journée (spec 009, « Définitions ») : salutation de l'accueil, titre
/// du check-in et scène de l'en-tête.
library;

/// « Jour » de 05:00 à 17:59, « soir » de 18:00 à 04:59, heure locale.
enum DayMoment { day, evening }

/// Moment de la journée de l'heure locale [now].
DayMoment dayMomentOf(DateTime now) =>
    now.hour >= 5 && now.hour < 18 ? DayMoment.day : DayMoment.evening;

/// Salutation de l'en-tête de l'accueil (CA7).
String greetingFor(DayMoment moment) => switch (moment) {
  DayMoment.day => 'Bonjour',
  DayMoment.evening => 'Bonsoir',
};

/// Titre de la carte du check-in (CA11).
String checkInTitleFor(DayMoment moment) => switch (moment) {
  DayMoment.day => "Comment va ta marée aujourd'hui ?",
  DayMoment.evening => 'Comment va ta marée ce soir ?',
};
