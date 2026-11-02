import 'package:dicoenfr_engine/dicoenfr_engine.dart';

/// Source en mémoire pour les tests du moteur.
class SourceMemoire implements Source {
  SourceMemoire();

  static const motGoV = Mot(id: 1, mot: 'go', nature: 'verb', rang: 5);
  static const motGoN = Mot(id: 2, mot: 'go', nature: 'noun', rang: 5);
  static const motDog = Mot(id: 3, mot: 'dog', nature: 'noun', rang: 80);
  static const motWorld = Mot(id: 4, mot: 'world', nature: 'noun', rang: 100);
  static const motTurn = Mot(id: 5, mot: 'turn', nature: 'verb', rang: 300);
  static const motTurned = Mot(id: 6, mot: 'turned', nature: 'adj', rang: 800);
  static const motHello = Mot(id: 7, mot: 'hello', nature: 'intj', rang: 900);

  final List<Mot> mots = const [motGoV, motGoN, motDog, motWorld, motTurn, motTurned, motHello];

  final Map<int, List<Equivalent>> equivalentsParMot = const {
    1: [
      Equivalent(fr: 'aller', etiquette: 'to move', source: 'en+fr'),
      Equivalent(fr: 'partir', source: 'en'),
    ],
    2: [Equivalent(fr: 'essai', genre: 'm', source: 'en')],
    3: [Equivalent(fr: 'chien', genre: 'm', source: 'en+fr')],
    4: [Equivalent(fr: 'monde', genre: 'm', source: 'en')],
    5: [Equivalent(fr: 'tourner', source: 'en')],
    7: [Equivalent(fr: 'bonjour', source: 'en+fr')],
  };

  final Map<String, List<Renvoi>> renvois = const {
    'went': [Renvoi(motGoV, 'past')],
    'turned': [Renvoi(motTurn, 'participle, past')],
  };

  final Map<int, List<Forme>> formesParMot = const {
    1: [
      Forme('goes', 'third-person, singular, present'),
      Forme('going', 'participle, present'),
      Forme('went', 'past'),
      Forme('gone', 'participle, past'),
    ],
  };

  /// Mot français (plié) → lignes inverses.
  final Map<String, List<LigneInverse>> inverses = const {
    'chien': [LigneInverse(motDog, Equivalent(fr: 'chien', genre: 'm', source: 'en+fr'))],
    'monde': [LigneInverse(motWorld, Equivalent(fr: 'monde', genre: 'm', source: 'en'))],
    'bonjour': [LigneInverse(motHello, Equivalent(fr: 'bonjour', source: 'en+fr'))],
  };

  @override
  Future<List<Mot>> motsParRecherche(String recherche) async =>
      mots.where((m) => plier(m.mot) == recherche).toList();

  @override
  Future<List<Renvoi>> lemmesDeForme(String forme) async => renvois[forme] ?? const [];

  @override
  Future<Contraction?> contraction(String forme) async => forme == "can't"
      ? const Contraction(forme: "can't", developpe: 'cannot', traduction: 'ne peut pas')
      : null;

  @override
  Future<List<Equivalent>> equivalents(int motId) async => equivalentsParMot[motId] ?? const [];

  @override
  Future<List<Sens>> sens(int motId) async =>
      [Sens(ordre: 1, definition: 'définition $motId')];

  @override
  Future<List<String>> definitionsFr(int motId) async => const [];

  @override
  Future<List<Forme>> formes(int motId) async => formesParMot[motId] ?? const [];

  @override
  Future<List<Audio>> audio(int motId) async => const [];

  @override
  Future<List<Prononciation>> prononciations(int motId) async => const [];

  @override
  Future<List<LigneInverse>> anglaisParFrancais(String recherche, int limite) async =>
      inverses[recherche] ?? const [];

  @override
  Future<List<String>> suggestionsAnglais(String prefixe, int limite) async => mots
      .map((m) => m.mot)
      .toSet()
      .where((m) => plier(m).startsWith(prefixe))
      .take(limite)
      .toList();

  @override
  Future<List<String>> suggestionsFrancais(String prefixe, int limite) async => inverses.keys
      .where((m) => m.startsWith(prefixe))
      .take(limite)
      .toList();
}
