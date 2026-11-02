/// Accès aux données, séparé du moteur : l'application branche SQLite (via [SourceSql]),
/// les tests branchent une source en mémoire.
library;

import 'modeles.dart';

abstract class Source {
  /// Mots dont la forme de recherche est exactement [recherche] (texte plié).
  Future<List<Mot>> motsParRecherche(String recherche);

  /// Mots de base de la forme [forme] (texte normalisé).
  Future<List<Renvoi>> lemmesDeForme(String forme);

  Future<Contraction?> contraction(String forme);

  Future<List<Equivalent>> equivalents(int motId);
  Future<List<Sens>> sens(int motId);
  Future<List<String>> definitionsFr(int motId);
  Future<List<Forme>> formes(int motId);
  Future<List<Audio>> audio(int motId);
  Future<List<Prononciation>> prononciations(int motId);

  /// Mots anglais dont un équivalent français correspond à [recherche] (texte plié).
  Future<List<LigneInverse>> anglaisParFrancais(String recherche, int limite);

  Future<List<String>> suggestionsAnglais(String prefixe, int limite);
  Future<List<String>> suggestionsFrancais(String prefixe, int limite);
}
