/// Objets échangés entre la base, le moteur et l'interface.
library;

/// Un mot anglais et sa nature grammaticale (noun, verb, adj, adv, intj, name…).
class Mot {
  const Mot({required this.id, required this.mot, required this.nature, this.rang});

  final int id;
  final String mot;
  final String nature;

  /// Rang de fréquence (1 = le plus courant), ou null.
  final int? rang;
}

/// Un équivalent français. [source] : 'en', 'fr' ou 'en+fr' (confirmé par les deux éditions).
class Equivalent {
  const Equivalent({required this.fr, this.etiquette = '', this.genre = '', this.source = ''});

  final String fr;
  final String etiquette;

  /// 'm', 'f', 'mf' ou vide.
  final String genre;
  final String source;

  bool get confirme => source == 'en+fr';
}

class Sens {
  const Sens({
    required this.ordre,
    required this.definition,
    this.contexte = '',
    this.etiquettes = '',
    this.exemple = '',
  });

  final int ordre;
  final String definition;
  final String contexte;
  final String etiquettes;
  final String exemple;
}

/// Forme fléchie listée par le mot de base, avec ses balises (« participle, past »).
class Forme {
  const Forme(this.forme, this.etiquettes);

  final String forme;
  final String etiquettes;
}

class Audio {
  const Audio(this.fichier, this.accent);

  final String fichier;

  /// 'us', 'uk', 'au' ou 'autre'.
  final String accent;
}

class Prononciation {
  const Prononciation(this.accent, this.api);

  final String accent;
  final String api;
}

class Contraction {
  const Contraction({required this.forme, required this.developpe, required this.traduction});

  final String forme;
  final String developpe;
  final String traduction;
}

/// Mot de base retrouvé à partir d'une forme (went → go), avec la nature du renvoi.
class Renvoi {
  const Renvoi(this.lemme, this.etiquettes);

  final Mot lemme;
  final String etiquettes;
}

/// Une ligne du sens français → anglais : un mot anglais et l'équivalent qui a été trouvé.
class LigneInverse {
  const LigneInverse(this.mot, this.equivalent);

  final Mot mot;
  final Equivalent equivalent;
}

/// Un mot anglais proposé pour un mot français, avec les équivalents français qui correspondent.
class EntreeInverse {
  const EntreeInverse(this.mot, this.equivalents);

  final Mot mot;
  final List<Equivalent> equivalents;

  bool get confirme => equivalents.any((e) => e.confirme);
}

/// Fiche complète d'un mot anglais.
class Fiche {
  const Fiche({
    required this.mot,
    this.equivalents = const [],
    this.sens = const [],
    this.definitionsFr = const [],
    this.formes = const [],
    this.audio = const [],
    this.prononciations = const [],
    this.formeDemandee,
    this.etiquetteRenvoi = '',
  });

  final Mot mot;
  final List<Equivalent> equivalents;
  final List<Sens> sens;
  final List<String> definitionsFr;
  final List<Forme> formes;
  final List<Audio> audio;
  final List<Prononciation> prononciations;

  /// Si la fiche est celle du mot de base d'une forme saisie (went → go) : la forme saisie.
  final String? formeDemandee;

  /// Nature du renvoi (« past », « plural »…), si la fiche vient d'une forme.
  final String etiquetteRenvoi;
}

enum Direction { anglaisFrancais, francaisAnglais }

/// Réponse à une recherche. Les deux sens sont cherchés : un mot comme « pain » ou « table »
/// existe dans les deux langues, c'est à l'interface de choisir l'onglet affiché.
class Resultat {
  const Resultat({
    required this.requete,
    this.fiches = const [],
    this.inverses = const [],
    this.contraction,
    this.regleAnglais,
    this.regleFrancais,
    this.suggestions = const [],
  });

  final String requete;

  /// Anglais → français.
  final List<Fiche> fiches;

  /// Français → anglais.
  final List<EntreeInverse> inverses;
  final Contraction? contraction;

  /// Explication si le résultat vient d'une règle (« possessif de world »).
  final String? regleAnglais;
  final String? regleFrancais;

  /// Mots proches, proposés quand rien n'est trouvé.
  final List<String> suggestions;

  bool get vide => fiches.isEmpty && inverses.isEmpty && contraction == null;

  /// Sens à afficher d'abord : l'anglais s'il y a des fiches, sinon le français.
  Direction get directionParDefaut =>
      fiches.isNotEmpty || contraction != null ? Direction.anglaisFrancais : Direction.francaisAnglais;
}
