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

  /// Synonymes, contraires et mots de la même famille.
  Future<List<Relation>> relations(int motId);

  /// Verbes à particule du verbe [base] (give → give up…).
  Future<List<String>> verbesAParticule(String base, int limite);

  /// Mots dont la première lettre est [initiale] et la longueur comprise entre [lmin] et [lmax],
  /// anglais ou français, pour corriger une faute de frappe.
  Future<List<MotProche>> motsProches(String initiale, int lmin, int lmax,
      {required bool francais, required int limite});

  /// Mots anglais dont la forme de recherche correspond au motif GLOB [glob], le début fixe du
  /// motif étant [debut].
  Future<List<String>> motsParMotif(String debut, String glob, int limite);

  /// Mots dont une définition contient tous les [termes] (au plus trois).
  Future<List<ParDefinition>> parDefinition(List<String> termes,
      {required bool francais, required int limite});

  /// Équivalents français pris au hasard : mauvaises réponses d'un quiz.
  Future<List<String>> equivalentsHasard(int nombre);

  /// Mots anglais courants pris au hasard : mauvaises réponses d'un quiz.
  Future<List<String>> motsHasard(int nombre);

  /// Faux amis pris au hasard.
  Future<List<FauxAmi>> fauxAmisHasard(int nombre);

  /// Faux ami, d'après le mot anglais en minuscules.
  Future<FauxAmi?> fauxAmi(String mot);

  /// Infos d'expression d'un mot, ou null si ce n'est pas une expression.
  Future<InfoExpression?> infoExpression(int motId);

  /// Expressions, les soignées d'abord. [type] et [theme] vides = tous ; [recherche] : texte brut.
  Future<List<LigneExpression>> expressions(
      {String type = '', String theme = '', bool vulgaire = false, String recherche = '',
      required int limite, int decalage = 0});

  /// Expressions qui contiennent le mot [motPlie].
  Future<List<LigneExpression>> expressionsAvec(String motPlie, {bool vulgaire = false, required int limite});

  /// Nombre d'expressions soignées (idiomes et proverbes) : base de « l'expression du jour ».
  Future<int> nombreExpressionsCurees();

  /// Expression soignée numéro [decalage] (0 = première).
  Future<LigneExpression?> expressionCuree(int decalage);

  /// Expressions soignées tirées au hasard (quiz).
  Future<List<LigneExpression>> expressionsCureesHasard(int nombre);

  /// Mots anglais dont un équivalent français correspond à [recherche] (texte plié).
  Future<List<LigneInverse>> anglaisParFrancais(String recherche, int limite);

  Future<List<String>> suggestionsAnglais(String prefixe, int limite);
  Future<List<String>> suggestionsFrancais(String prefixe, int limite);
}
