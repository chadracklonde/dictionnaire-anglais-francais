/// Recherche anglais ↔ français : formes fléchies, renvois, contractions, possessifs, règles
/// régulières, suggestions. Ne connaît la base qu'à travers [Source].
library;

import 'conjugaison.dart';
import 'modeles.dart';
import 'normalisation.dart';
import 'regles.dart';
import 'source.dart';

class _Anglais {
  const _Anglais(this.fiches, this.contraction, this.regle);

  final List<Fiche> fiches;
  final Contraction? contraction;
  final String? regle;
}

class _Francais {
  const _Francais(this.entrees, this.regle);

  final List<EntreeInverse> entrees;
  final String? regle;
}

class Moteur {
  Moteur(this.source);

  final Source source;

  /// Nombre maximal de fiches ouvertes pour une même requête.
  static const int maxFiches = 8;

  /// Nombre de lignes lues pour le sens français → anglais.
  static const int maxLignesInverses = 120;

  /// Cherche [texte] dans les deux sens.
  Future<Resultat> chercher(String texte) async {
    final q = normaliser(texte);
    if (q.isEmpty) return Resultat(requete: texte);
    final en = await _anglais(q);
    final fr = await _francais(q);
    var suggestions = const <String>[];
    if (en.fiches.isEmpty && fr.entrees.isEmpty && en.contraction == null) {
      suggestions = await suggestionsApprochees(q);
    }
    return Resultat(
      requete: texte.trim(),
      fiches: en.fiches,
      inverses: fr.entrees,
      contraction: en.contraction,
      regleAnglais: en.regle,
      regleFrancais: fr.regle,
      suggestions: suggestions,
    );
  }

  /// Fiche d'un mot connu par son identifiant (liste de résultats, favoris, historique…).
  Future<Fiche> fiche(Mot mot, {String? formeDemandee, String etiquetteRenvoi = ''}) async {
    final r = await Future.wait<Object>([
      source.equivalents(mot.id),
      source.sens(mot.id),
      source.definitionsFr(mot.id),
      source.formes(mot.id),
      source.audio(mot.id),
      source.prononciations(mot.id),
    ]);
    return Fiche(
      mot: mot,
      equivalents: r[0] as List<Equivalent>,
      sens: r[1] as List<Sens>,
      definitionsFr: r[2] as List<String>,
      formes: r[3] as List<Forme>,
      audio: r[4] as List<Audio>,
      prononciations: r[5] as List<Prononciation>,
      formeDemandee: formeDemandee,
      etiquetteRenvoi: etiquetteRenvoi,
    );
  }

  /// Conjugaison anglaise d'un verbe : formes de la base d'abord, règles pour le reste.
  Future<Conjugaison> conjuguerMot(Mot mot, {Polarite polarite = Polarite.affirmative}) async {
    return conjuguer(mot.mot, formesBdd: await source.formes(mot.id), polarite: polarite);
  }

  /// Suggestions pendant la frappe : mots anglais d'abord, puis français.
  Future<List<String>> suggerer(String texte, {int limite = 8}) async {
    final p = plier(texte);
    if (p.length < 2) return const [];
    final anglais = await source.suggestionsAnglais(p, limite);
    final sortie = <String>[...anglais];
    if (sortie.length < limite) {
      final francais = await source.suggestionsFrancais(p, limite - sortie.length);
      for (final mot in francais) {
        if (!sortie.contains(mot)) sortie.add(mot);
      }
    }
    return sortie;
  }

  /// Quand rien n'est trouvé : mots qui commencent comme la requête, en la raccourcissant.
  Future<List<String>> suggestionsApprochees(String requete, {int limite = 8}) async {
    final p = plier(requete);
    for (var n = p.length - 1; n >= 2 && n >= p.length - 4; n--) {
      final trouves = await suggerer(p.substring(0, n), limite: limite);
      if (trouves.isNotEmpty) return trouves;
    }
    return const [];
  }

  // ------------------------------------------------------------------ anglais → français

  Future<_Anglais> _anglais(String q) async {
    final contraction = await source.contraction(q);
    var fiches = await _fichesPour(q);
    String? regle;
    if (!_aEquivalent(fiches) && contraction == null) {
      final base = sansPossessif(q);
      if (base != null) {
        var dePossessif = await _fichesPour(base);
        String? sousRegle;
        if (!_aEquivalent(dePossessif)) {
          final parRegles = await _parRegles(base);
          if (parRegles != null) {
            dePossessif = _devant(parRegles.fiches, dePossessif);
            sousRegle = parRegles.regle;
          }
        }
        if (dePossessif.isNotEmpty) {
          fiches = _devant(dePossessif, fiches);
          regle = 'possessif de « $base »${sousRegle == null ? '' : ' ; $sousRegle'}';
        }
      } else {
        final parRegles = await _parRegles(q);
        if (parRegles != null) {
          fiches = _devant(parRegles.fiches, fiches);
          regle = parRegles.regle;
        }
      }
    }
    return _Anglais(fiches, contraction, regle);
  }

  /// Essaie les mots de base probables de [mot] ; renvoie le premier qui a des équivalents.
  Future<_Anglais?> _parRegles(String mot) async {
    for (final candidat in candidatsLemmes(mot)) {
      final trouvees = await _fichesPour(candidat.lemme);
      if (_aEquivalent(trouvees)) {
        return _Anglais(trouvees, null,
            'forme probable de « ${candidat.lemme} » (${candidat.description})');
      }
    }
    return null;
  }

  static bool _aEquivalent(List<Fiche> fiches) => fiches.any((f) => f.equivalents.isNotEmpty);

  /// [avant] puis les fiches de [apres] qui ne sont pas déjà dedans.
  static List<Fiche> _devant(List<Fiche> avant, List<Fiche> apres) {
    final ids = avant.map((f) => f.mot.id).toSet();
    return [...avant, ...apres.where((f) => !ids.contains(f.mot.id))];
  }

  Future<List<Fiche>> _fichesPour(String q) async {
    final directs = await source.motsParRecherche(plier(q));
    final renvois = await source.lemmesDeForme(q);
    final vus = <int>{};
    final demandes = <Future<Fiche>>[];
    for (final mot in directs) {
      if (demandes.length < maxFiches && vus.add(mot.id)) demandes.add(fiche(mot));
    }
    for (final renvoi in renvois) {
      if (demandes.length < maxFiches + 4 && vus.add(renvoi.lemme.id)) {
        demandes.add(fiche(renvoi.lemme, formeDemandee: q, etiquetteRenvoi: renvoi.etiquettes));
      }
    }
    final fiches = await Future.wait(demandes);
    // Les fiches qui ont des équivalents passent devant, sans bouleverser l'ordre de fréquence.
    final avecIndice = <MapEntry<int, Fiche>>[
      for (var i = 0; i < fiches.length; i++) MapEntry(i, fiches[i]),
    ];
    avecIndice.sort((a, b) {
      final ea = a.value.equivalents.isEmpty ? 1 : 0;
      final eb = b.value.equivalents.isEmpty ? 1 : 0;
      return ea != eb ? ea - eb : a.key - b.key;
    });
    return [for (final e in avecIndice) e.value];
  }

  // ------------------------------------------------------------------ français → anglais

  Future<_Francais> _francais(String q) async {
    final p = plier(q);
    var lignes = await source.anglaisParFrancais(p, maxLignesInverses);
    String? regle;
    if (lignes.isEmpty) {
      for (final candidat in candidatsFrancais(p)) {
        lignes = await source.anglaisParFrancais(candidat.lemme, maxLignesInverses);
        if (lignes.isNotEmpty) {
          regle = 'forme probable de « ${candidat.lemme} » (${candidat.description})';
          break;
        }
      }
    }
    return _Francais(_grouper(lignes), regle);
  }

  static List<EntreeInverse> _grouper(List<LigneInverse> lignes) {
    final mots = <int, Mot>{};
    final equivalents = <int, List<Equivalent>>{};
    for (final ligne in lignes) {
      mots.putIfAbsent(ligne.mot.id, () => ligne.mot);
      equivalents.putIfAbsent(ligne.mot.id, () => <Equivalent>[]).add(ligne.equivalent);
    }
    final entrees = [for (final id in mots.keys) EntreeInverse(mots[id]!, equivalents[id]!)];
    final indices = <EntreeInverse, int>{for (var i = 0; i < entrees.length; i++) entrees[i]: i};
    entrees.sort((a, b) {
      final ca = a.confirme ? 0 : 1;
      final cb = b.confirme ? 0 : 1;
      if (ca != cb) return ca - cb;
      return indices[a]! - indices[b]!;
    });
    return entrees;
  }
}
