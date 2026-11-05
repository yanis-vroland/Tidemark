/// Sujet d'une entrée (glossaire : `Topic`, spec 010) : ce qui a compté pour la
/// personne, qu'elle choisit elle-même à la saisie. Liste fixe et ordonnée : l'ordre
/// des valeurs est celui de l'affichage, de l'enregistrement et de l'export.
library;

enum Topic {
  sommeil,
  travail,
  amis,
  famille,
  sport,
  nature;

  /// Libellé affiché et exporté : le nom du sujet.
  String get label => name;
}

/// [topics] sans doublon, dans l'ordre de la liste (spec 010, CA4).
List<Topic> topicsInListOrder(Iterable<Topic> topics) {
  final chosen = topics.toSet();
  return [
    for (final topic in Topic.values)
      if (chosen.contains(topic)) topic,
  ];
}
