/// [Source] sur une base SQLite, via un exécuteur minimal que l'application fournit
/// (sqflite sur Android, sqlite3 sur ordinateur). Les requêtes sont dans requetes.dart.
library;

import 'modeles.dart';
import 'normalisation.dart';
import 'requetes.dart';
import 'source.dart';

/// Une entrée de l'index alphabétique : le mot affiché et sa clé de tri.
class EntreeIndex {
  const EntreeIndex(this.mot, this.cle);

  final String mot;
  final String cle;
}

abstract class ExecuteurSql {
  Future<List<Map<String, Object?>>> requete(String sql, [List<Object?> arguments = const []]);
}

class SourceSql implements Source {
  SourceSql(this._sql);

  final ExecuteurSql _sql;

  static int _entier(Object? valeur) => (valeur as num).toInt();
  static int? _entierOuNull(Object? valeur) => valeur == null ? null : (valeur as num).toInt();
  static String _texte(Object? valeur) => valeur == null ? '' : valeur as String;

  static Mot _mot(Map<String, Object?> ligne) => Mot(
        id: _entier(ligne['id']),
        mot: _texte(ligne['mot']),
        nature: _texte(ligne['nature']),
        rang: _entierOuNull(ligne['rang']),
      );

  static Equivalent _equivalent(Map<String, Object?> ligne) => Equivalent(
        fr: _texte(ligne['fr']),
        etiquette: _texte(ligne['etiquette']),
        genre: _texte(ligne['genre']),
        source: _texte(ligne['source']),
      );

  /// Borne supérieure (exclue) d'un parcours par préfixe.
  static String borneSuperieure(String prefixe) => '$prefixe￿';

  @override
  Future<List<Mot>> motsParRecherche(String recherche) async {
    final lignes = await _sql.requete(requeteMotsParRecherche, [recherche]);
    return lignes.map(_mot).toList();
  }

  @override
  Future<List<Renvoi>> lemmesDeForme(String forme) async {
    final lignes = await _sql.requete(requeteLemmesDeForme, [forme]);
    return lignes.map((l) => Renvoi(_mot(l), _texte(l['etiquettes']))).toList();
  }

  @override
  Future<Contraction?> contraction(String forme) async {
    final lignes = await _sql.requete(requeteContraction, [forme]);
    if (lignes.isEmpty) return null;
    final l = lignes.first;
    return Contraction(
      forme: _texte(l['forme']),
      developpe: _texte(l['developpe']),
      traduction: _texte(l['traduction']),
    );
  }

  @override
  Future<List<Equivalent>> equivalents(int motId) async {
    final lignes = await _sql.requete(requeteEquivalents, [motId]);
    return lignes.map(_equivalent).toList();
  }

  @override
  Future<List<Sens>> sens(int motId) async {
    final lignes = await _sql.requete(requeteSens, [motId]);
    return lignes
        .map((l) => Sens(
              ordre: _entier(l['ordre']),
              definition: _texte(l['definition']),
              contexte: _texte(l['contexte']),
              etiquettes: _texte(l['etiquettes']),
              exemple: _texte(l['exemple']),
            ))
        .toList();
  }

  @override
  Future<List<String>> definitionsFr(int motId) async {
    final lignes = await _sql.requete(requeteDefinitionsFr, [motId]);
    return lignes.map((l) => _texte(l['texte'])).toList();
  }

  @override
  Future<List<Forme>> formes(int motId) async {
    final lignes = await _sql.requete(requeteFormes, [motId]);
    return lignes.map((l) => Forme(_texte(l['forme']), _texte(l['etiquettes']))).toList();
  }

  @override
  Future<List<Audio>> audio(int motId) async {
    final lignes = await _sql.requete(requeteAudio, [motId]);
    return lignes.map((l) => Audio(_texte(l['fichier']), _texte(l['accent']))).toList();
  }

  @override
  Future<List<Prononciation>> prononciations(int motId) async {
    final lignes = await _sql.requete(requetePrononciations, [motId]);
    return lignes.map((l) => Prononciation(_texte(l['accent']), _texte(l['api']))).toList();
  }

  @override
  Future<List<MotProche>> motsProches(String initiale, int lmin, int lmax,
      {required bool francais, required int limite}) async {
    final lignes = await _sql.requete(
      francais ? requeteMotsProchesFrancais : requeteMotsProchesAnglais,
      [initiale, borneSuperieure(initiale), lmin, lmax, limite],
    );
    return lignes
        .map((l) => MotProche(_texte(l['mot']), _texte(l['recherche']), _entierOuNull(l['rang'])))
        .toList();
  }

  @override
  Future<List<String>> motsParMotif(String debut, String glob, int limite) async {
    final lignes = await _sql.requete(
      requeteMotsParMotif,
      [debut, borneSuperieure(debut), glob, limite],
    );
    return lignes.map((l) => _texte(l['mot'])).toList();
  }

  @override
  Future<List<ParDefinition>> parDefinition(List<String> termes,
      {required bool francais, required int limite}) async {
    final motifs = [for (final t in termes.take(3)) '%$t%'];
    while (motifs.length < 3) {
      motifs.add('%');
    }
    final lignes = await _sql.requete(
      francais ? requeteParDefinitionFrancaise : requeteParDefinitionAnglaise,
      [...motifs, limite],
    );
    return lignes.map((l) => ParDefinition(_mot(l), _texte(l['extrait']))).toList();
  }

  @override
  Future<List<String>> equivalentsHasard(int nombre) async {
    final lignes = await _sql.requete(requeteEquivalentsHasard, [nombre]);
    return lignes.map((l) => _texte(l['fr'])).toList();
  }

  @override
  Future<List<String>> motsHasard(int nombre) async {
    final lignes = await _sql.requete(requeteMotsHasard, [nombre]);
    return lignes.map((l) => _texte(l['mot'])).toList();
  }

  @override
  Future<List<FauxAmi>> fauxAmisHasard(int nombre) async {
    final lignes = await _sql.requete(requeteFauxAmisHasard, [nombre]);
    return lignes
        .map((l) => FauxAmi(mot: _texte(l['mot']), piege: _texte(l['piege']), vrai: _texte(l['vrai'])))
        .toList();
  }

  @override
  Future<List<Relation>> relations(int motId) async {
    final lignes = await _sql.requete(requeteRelations, [motId]);
    return lignes.map((l) => Relation(_texte(l['type']), _texte(l['mot']))).toList();
  }

  @override
  Future<List<String>> verbesAParticule(String base, int limite) async {
    final p = plier(base);
    if (p.isEmpty) return const [];
    final lignes = await _sql.requete(requeteVerbesAParticule, ['$p ', '$p!', limite]);
    return lignes.map((l) => _texte(l['mot'])).toList();
  }

  @override
  Future<FauxAmi?> fauxAmi(String mot) async {
    final lignes = await _sql.requete(requeteFauxAmi, [mot]);
    if (lignes.isEmpty) return null;
    final l = lignes.first;
    return FauxAmi(mot: _texte(l['mot']), piege: _texte(l['piege']), vrai: _texte(l['vrai']));
  }

  @override
  Future<List<LigneInverse>> anglaisParFrancais(String recherche, int limite) async {
    final lignes = await _sql.requete(requeteAnglaisParFrancais, [recherche, limite]);
    return lignes.map((l) => LigneInverse(_mot(l), _equivalent(l))).toList();
  }

  @override
  Future<List<String>> suggestionsAnglais(String prefixe, int limite) async {
    final lignes =
        await _sql.requete(requeteSuggestionsAnglais, [prefixe, borneSuperieure(prefixe), limite]);
    return lignes.map((l) => _texte(l['mot'])).toList();
  }

  @override
  Future<List<String>> suggestionsFrancais(String prefixe, int limite) async {
    final lignes =
        await _sql.requete(requeteSuggestionsFrancais, [prefixe, borneSuperieure(prefixe), limite]);
    return lignes.map((l) => _texte(l['fr'])).toList();
  }

  /// Page de l'index alphabétique : les [limite] mots qui suivent la clé [apres] ('' pour le début).
  Future<List<EntreeIndex>> indexAnglais(String apres, int limite) async {
    final lignes = await _sql.requete(requeteIndexAnglais, [apres, limite]);
    return lignes.map((l) => EntreeIndex(_texte(l['mot']), _texte(l['cle']))).toList();
  }

  /// Nombre de mots, de traductions, de verbes et de fichiers audio.
  Future<Map<String, int>> chiffres() async {
    final lignes = await _sql.requete(requeteChiffres);
    if (lignes.isEmpty) return const {};
    final l = lignes.first;
    return {
      'mots': _entier(l['mots']),
      'traductions': _entier(l['traductions']),
      'verbes': _entier(l['verbes']),
      'audio': _entier(l['audio']),
    };
  }

  Future<Map<String, String>> meta() async {
    final lignes = await _sql.requete(requeteMeta);
    return {for (final l in lignes) _texte(l['cle']): _texte(l['valeur'])};
  }
}
