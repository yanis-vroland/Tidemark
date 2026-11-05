/// Sujet d'une entrée (glossaire : `Topic`, spec 010) : ce qui a compté pour la
/// personne, qu'elle choisit elle-même à la saisie. Liste fixe et ordonnée : l'ordre
/// des valeurs est celui de l'affichage, de l'enregistrement et de l'export.
///
/// En base, un sujet s'écrit par son nom anglais ([Enum.name]) ; à l'écran et dans
/// l'export, par son libellé français ([label]).
library;

enum Topic {
  sleep('sommeil'),
  work('travail'),
  friends('amis'),
  family('famille'),
  sport('sport'),
  nature('nature');

  const Topic(this.label);

  /// Libellé affiché et exporté, en français.
  final String label;
}

/// [topics] sans doublon, dans l'ordre de la liste (spec 010, CA4).
List<Topic> topicsInListOrder(Iterable<Topic> topics) {
  final chosen = topics.toSet();
  return [
    for (final topic in Topic.values)
      if (chosen.contains(topic)) topic,
  ];
}
