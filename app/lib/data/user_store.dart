import 'dart:convert';

import 'package:dicoenfr_engine/dicoenfr_engine.dart'
    show Carte, meilleureSerie, motsDifficiles, numeroDeJour, serieEnCours;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris, historique et réglages, enregistrés sur l'appareil.
/// Un mot est repéré par la clé « mot<TAB>nature » (voir [cle]).
class UserStore extends ChangeNotifier {
  UserStore(this._prefs)
      : favoris = List.of(_prefs.getStringList('favoris') ?? const []),
        historique = List.of(_prefs.getStringList('historique') ?? const []),
        notes = _decoderNotes(_prefs.getString('notes')),
        listes = _decoderListes(_prefs.getString('listes')),
        revisions = _decoderRevisions(_prefs.getString('revisions')),
        activite = _decoderActivite(_prefs.getString('activite'));

  static const int _historiqueMax = 100;

  final SharedPreferences _prefs;
  final List<String> favoris;
  final List<String> historique;

  /// Notes personnelles : clé du mot → texte.
  final Map<String, String> notes;

  /// Listes personnelles : nom → clés des mots (dans l'ordre d'ajout).
  final Map<String, List<String>> listes;

  /// Cartes de révision : clé du mot → état de la carte.
  final Map<String, Carte> revisions;

  static Map<String, Carte> _decoderRevisions(String? brut) {
    final resultat = <String, Carte>{};
    if (brut == null) return resultat;
    try {
      final data = jsonDecode(brut);
      if (data is Map) {
        data.forEach((k, v) {
          final carte = Carte.depuisJson(v);
          if (k is String && carte != null) resultat[k] = carte;
        });
      }
    } catch (_) {}
    return resultat;
  }

  /// Activité par jour : numéro du jour → [réponses données, nouveaux mots vus].
  final Map<int, List<int>> activite;

  static Map<int, List<int>> _decoderActivite(String? brut) {
    final resultat = <int, List<int>>{};
    if (brut == null) return resultat;
    try {
      final data = jsonDecode(brut);
      if (data is Map) {
        data.forEach((k, v) {
          final jour = int.tryParse('$k');
          if (jour != null && v is List && v.length >= 2 && v[0] is int && v[1] is int) {
            resultat[jour] = [v[0] as int, v[1] as int];
          }
        });
      }
    } catch (_) {}
    return resultat;
  }

  static const int _joursConserves = 120;

  static const int _noteMax = 2000;
  static const int _nomListeMax = 60;

  static Map<String, String> _decoderNotes(String? brut) {
    final resultat = <String, String>{};
    if (brut == null) return resultat;
    try {
      final data = jsonDecode(brut);
      if (data is Map) {
        data.forEach((k, v) {
          if (k is String && v is String && v.trim().isNotEmpty) resultat[k] = v;
        });
      }
    } catch (_) {}
    return resultat;
  }

  static Map<String, List<String>> _decoderListes(String? brut) {
    final resultat = <String, List<String>>{};
    if (brut == null) return resultat;
    try {
      final data = jsonDecode(brut);
      if (data is Map) {
        data.forEach((k, v) {
          if (k is String && k.trim().isNotEmpty && v is List) {
            resultat[k] = [for (final x in v) if (x is String && x.isNotEmpty) x];
          }
        });
      }
    } catch (_) {}
    return resultat;
  }

  Future<void> _enregistrerNotes() async {
    await _prefs.setString('notes', jsonEncode(notes));
    notifyListeners();
  }

  Future<void> _enregistrerListes() async {
    await _prefs.setString('listes', jsonEncode(listes));
    notifyListeners();
  }

  // ---- Notes ----

  String noteDe(String cle) => notes[cle] ?? '';

  /// Enregistre la note d'un mot ; un texte vide la supprime.
  Future<void> definirNote(String cle, String texte) async {
    var t = texte.trim();
    if (t.length > _noteMax) t = t.substring(0, _noteMax);
    if (t.isEmpty) {
      notes.remove(cle);
    } else {
      notes[cle] = t;
    }
    await _enregistrerNotes();
  }

  // ---- Listes ----

  /// Crée une liste. Renvoie false si le nom est vide ou déjà pris (sans tenir compte de la casse).
  Future<bool> creerListe(String nom) async {
    var n = nom.trim();
    if (n.length > _nomListeMax) n = n.substring(0, _nomListeMax);
    if (n.isEmpty) return false;
    if (listes.keys.any((k) => k.toLowerCase() == n.toLowerCase())) return false;
    listes[n] = [];
    await _enregistrerListes();
    return true;
  }

  Future<void> supprimerListe(String nom) async {
    if (listes.remove(nom) == null) return;
    await _enregistrerListes();
  }

  /// Remet une liste supprimée (annulation).
  Future<void> restaurerListe(String nom, List<String> mots) async {
    listes[nom] = List.of(mots);
    await _enregistrerListes();
  }

  bool estDansListe(String nom, String cle) => listes[nom]?.contains(cle) ?? false;

  Future<void> basculerDansListe(String nom, String cle) async {
    final liste = listes[nom];
    if (liste == null) return;
    if (!liste.remove(cle)) liste.add(cle);
    await _enregistrerListes();
  }

  /// Remet un mot dans une liste à sa place (annulation).
  Future<void> insererDansListe(String nom, int index, String cle) async {
    final liste = listes[nom];
    if (liste == null || liste.contains(cle)) return;
    liste.insert(index.clamp(0, liste.length), cle);
    await _enregistrerListes();
  }

  // ---- Révision ----

  /// État de la carte d'un mot (neuve si le mot n'a jamais été révisé).
  Carte carteDe(String cle) => revisions[cle] ?? const Carte();

  /// Enregistre une réponse (su ou non) pour un mot.
  Future<void> repondre(String cle, bool connu) async {
    final jour = numeroDeJour(DateTime.now());
    final neuve = carteDe(cle).vus == 0;
    final jourActuel = activite.putIfAbsent(jour, () => [0, 0]);
    jourActuel[0]++;
    if (neuve) jourActuel[1]++;
    if (activite.length > _joursConserves) {
      final anciens = activite.keys.toList()..sort();
      for (final j in anciens.take(activite.length - _joursConserves)) {
        activite.remove(j);
      }
    }
    await _prefs.setString(
        'activite', jsonEncode({for (final e in activite.entries) '${e.key}': e.value}));
    revisions[cle] = carteDe(cle).apresReponse(connu, jour);
    await _prefs.setString(
        'revisions', jsonEncode({for (final e in revisions.entries) e.key: e.value.versJson()}));
    notifyListeners();
  }

  /// Mots à réviser aujourd'hui parmi [cles] : d'abord les mots déjà vus, les plus en retard en tête,
  /// puis les nouveaux mots, dans la limite du nombre de nouveaux mots par jour.
  List<String> aReviser(Iterable<String> cles) {
    final jour = numeroDeJour(DateTime.now());
    final dues = <String>[];
    final neuves = <String>[];
    for (final c in cles) {
      final carte = carteDe(c);
      if (!carte.estDue(jour)) continue;
      (carte.vus == 0 ? neuves : dues).add(c);
    }
    dues.sort((a, b) => carteDe(a).prochaine.compareTo(carteDe(b).prochaine));
    final reste = nouveauxParJour - nouveauxAujourdhui;
    return [...dues, ...neuves.take(reste < 0 ? 0 : reste)];
  }

  /// Nombre de réponses données aujourd'hui.
  int get reponsesAujourdhui => activite[numeroDeJour(DateTime.now())]?[0] ?? 0;

  /// Nombre de nouveaux mots vus aujourd'hui.
  int get nouveauxAujourdhui => activite[numeroDeJour(DateTime.now())]?[1] ?? 0;

  int get serie => serieEnCours(activite.keys, numeroDeJour(DateTime.now()));

  int get meilleureSerieJours => meilleureSerie(activite.keys);

  /// Mots souvent ratés parmi [cles].
  List<String> difficiles(Iterable<String> cles) => motsDifficiles(revisions, cles);

  /// Tous les mots qu'on peut réviser : favoris et mots des listes, sans doublon.
  List<String> motsARevoir() {
    final vus = <String>{...favoris};
    for (final liste in listes.values) {
      vus.addAll(liste);
    }
    return vus.toList();
  }

  // ---- Sauvegarde ----

  /// Favoris, notes et listes sous forme de texte JSON (l'historique et les réglages restent locaux).
  String exporter() => const JsonEncoder.withIndent('  ').convert({
        'application': 'dicoenfr',
        'version': 1,
        'favoris': favoris,
        'notes': notes,
        'listes': listes,
        'revisions': {for (final e in revisions.entries) e.key: e.value.versJson()},
        'activite': {for (final e in activite.entries) '${e.key}': e.value},
      });

  /// Fusionne une sauvegarde : les favoris et mots de listes absents sont ajoutés, les notes
  /// du fichier remplacent celles du même mot. Lève [FormatException] si le texte n'est pas valide.
  Future<ResumeImport> importer(String texte) async {
    final dynamic data;
    try {
      data = jsonDecode(texte);
    } catch (_) {
      throw const FormatException('Le texte n\'est pas une sauvegarde valide.');
    }
    if (data is! Map || data['application'] != 'dicoenfr') {
      throw const FormatException('Ce texte ne vient pas d\'Anglais Français.');
    }
    var nbFavoris = 0, nbNotes = 0, nbListes = 0;
    final fav = data['favoris'];
    if (fav is List) {
      for (final c in fav) {
        if (c is String && c.isNotEmpty && !favoris.contains(c)) {
          favoris.add(c);
          nbFavoris++;
        }
      }
    }
    final nts = data['notes'];
    if (nts is Map) {
      nts.forEach((k, v) {
        if (k is String && k.isNotEmpty && v is String && v.trim().isNotEmpty) {
          notes[k] = v.trim().length > _noteMax ? v.trim().substring(0, _noteMax) : v.trim();
          nbNotes++;
        }
      });
    }
    final lst = data['listes'];
    if (lst is Map) {
      lst.forEach((k, v) {
        if (k is! String || k.trim().isEmpty || v is! List) return;
        final nom = k.trim().length > _nomListeMax ? k.trim().substring(0, _nomListeMax) : k.trim();
        final existante = listes.keys.where((x) => x.toLowerCase() == nom.toLowerCase());
        final cible = existante.isEmpty ? (listes[nom] = <String>[]) : listes[existante.first]!;
        if (existante.isEmpty) nbListes++;
        for (final c in v) {
          if (c is String && c.isNotEmpty && !cible.contains(c)) cible.add(c);
        }
      });
    }
    final rev = data['revisions'];
    if (rev is Map) {
      rev.forEach((k, v) {
        final carte = Carte.depuisJson(v);
        // On garde la carte la plus avancée (la plus souvent révisée) entre l'appareil et le fichier.
        if (k is String && k.isNotEmpty && carte != null && carte.vus > carteDe(k).vus) {
          revisions[k] = carte;
        }
      });
      await _prefs.setString(
          'revisions', jsonEncode({for (final e in revisions.entries) e.key: e.value.versJson()}));
    }
    final act = data['activite'];
    if (act is Map) {
      act.forEach((k, v) {
        final jour = int.tryParse('$k');
        if (jour != null && v is List && v.length >= 2 && v[0] is int && v[1] is int) {
          final actuel = activite[jour];
          if (actuel == null || (v[0] as int) > actuel[0]) activite[jour] = [v[0] as int, v[1] as int];
        }
      });
      await _prefs.setString(
          'activite', jsonEncode({for (final e in activite.entries) '${e.key}': e.value}));
    }
    await _prefs.setStringList('favoris', favoris);
    await _prefs.setString('notes', jsonEncode(notes));
    await _prefs.setString('listes', jsonEncode(listes));
    notifyListeners();
    return ResumeImport(favoris: nbFavoris, notes: nbNotes, listes: nbListes);
  }

  static String cle(String mot, String nature) => '$mot\t$nature';

  /// Découpe une clé en (mot, nature).
  static (String, String) decouper(String cle) {
    final i = cle.indexOf('\t');
    return i < 0 ? (cle, '') : (cle.substring(0, i), cle.substring(i + 1));
  }

  String get themeMode => _prefs.getString('themeMode') ?? 'system';
  double get textScale => _prefs.getDouble('textScale') ?? 1.0;

  /// Réponses visées par jour (objectif affiché sur l'onglet Réviser).
  int get objectifJour => _prefs.getInt('objectifJour') ?? 10;

  Future<void> setObjectifJour(int valeur) async {
    await _prefs.setInt('objectifJour', valeur);
    notifyListeners();
  }

  /// Nombre maximal de nouveaux mots proposés par jour.
  int get nouveauxParJour => _prefs.getInt('nouveauxParJour') ?? 10;

  Future<void> setNouveauxParJour(int valeur) async {
    await _prefs.setInt('nouveauxParJour', valeur);
    notifyListeners();
  }

  /// Rappel quotidien de révision (notification locale) : activé ou non, et heure en minutes depuis minuit.
  bool get rappelActif => _prefs.getBool('rappelActif') ?? false;
  int get rappelMinutes => _prefs.getInt('rappelMinutes') ?? 18 * 60;

  Future<void> setRappel({required bool actif, int? minutes}) async {
    await _prefs.setBool('rappelActif', actif);
    if (minutes != null) await _prefs.setInt('rappelMinutes', minutes);
    notifyListeners();
  }

  /// Afficher aussi les expressions vulgaires (masquées par défaut).
  bool get afficherVulgaire => _prefs.getBool('afficherVulgaire') ?? false;

  Future<void> setAfficherVulgaire(bool valeur) async {
    await _prefs.setBool('afficherVulgaire', valeur);
    notifyListeners();
  }

  bool get tutorielVu => _prefs.getBool('tutorielVu') ?? false;

  Future<void> setTutorielVu() async {
    await _prefs.setBool('tutorielVu', true);
    notifyListeners();
  }

  /// Accent de la voix : 'us' ou 'uk'.
  String get accent => _prefs.getString('accent') ?? 'us';

  Future<void> setThemeMode(String valeur) async {
    await _prefs.setString('themeMode', valeur);
    notifyListeners();
  }

  Future<void> setTextScale(double valeur) async {
    await _prefs.setDouble('textScale', valeur);
    notifyListeners();
  }

  Future<void> setAccent(String valeur) async {
    await _prefs.setString('accent', valeur);
    notifyListeners();
  }

  bool estFavori(String cle) => favoris.contains(cle);

  Future<void> basculerFavori(String cle) async {
    if (!favoris.remove(cle)) favoris.insert(0, cle);
    await _prefs.setStringList('favoris', favoris);
    notifyListeners();
  }

  /// Remet un favori à sa place (annulation d'une suppression).
  Future<void> insererFavori(int index, String cle) async {
    if (favoris.contains(cle)) return;
    favoris.insert(index.clamp(0, favoris.length), cle);
    await _prefs.setStringList('favoris', favoris);
    notifyListeners();
  }

  /// Remplace tout l'historique (annulation d'un effacement).
  Future<void> restaurerHistorique(List<String> cles) async {
    historique
      ..clear()
      ..addAll(cles);
    await _prefs.setStringList('historique', historique);
    notifyListeners();
  }

  Future<void> ajouterHistorique(String cle) async {
    historique.remove(cle);
    historique.insert(0, cle);
    if (historique.length > _historiqueMax) {
      historique.removeRange(_historiqueMax, historique.length);
    }
    await _prefs.setStringList('historique', historique);
    notifyListeners();
  }

  Future<void> viderHistorique() async {
    historique.clear();
    await _prefs.setStringList('historique', historique);
    notifyListeners();
  }
}

/// Ce qu'une importation a ajouté ou modifié.
class ResumeImport {
  const ResumeImport({required this.favoris, required this.notes, required this.listes});

  final int favoris;
  final int notes;
  final int listes;
}
