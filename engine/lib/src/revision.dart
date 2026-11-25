/// Cartes de révision à répétition espacée (méthode des boîtes de Leitner) : un mot su remonte
/// d'une boîte et revient plus tard, un mot oublié retombe dans la première boîte.
library;

import 'dart:math' as math;

/// Jours d'attente avant la prochaine révision, selon la boîte (0 à 6).
const List<int> intervallesJours = [0, 1, 2, 4, 8, 16, 32];

/// Numéro du jour (jours écoulés depuis le 1er janvier 1970, d'après le calendrier local).
int numeroDeJour(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

class Carte {
  const Carte({this.niveau = 0, this.prochaine = 0, this.vus = 0, this.justes = 0});

  /// Boîte actuelle (0 = à apprendre).
  final int niveau;

  /// Numéro du jour à partir duquel la carte est à réviser.
  final int prochaine;

  /// Nombre de réponses données, dont [justes] bonnes.
  final int vus;
  final int justes;

  bool estDue(int jour) => prochaine <= jour;

  /// Maîtrisée : arrivée dans la dernière boîte.
  bool get maitrisee => niveau >= intervallesJours.length - 1;

  /// La carte après une réponse faite le [jour].
  Carte apresReponse(bool connu, int jour) {
    if (!connu) {
      return Carte(niveau: 0, prochaine: jour, vus: vus + 1, justes: justes);
    }
    final n = math.min(niveau + 1, intervallesJours.length - 1);
    return Carte(
      niveau: n,
      prochaine: jour + intervallesJours[n],
      vus: vus + 1,
      justes: justes + 1,
    );
  }

  Map<String, int> versJson() => {'n': niveau, 'p': prochaine, 'v': vus, 'j': justes};

  /// Relit une carte enregistrée ; renvoie null si le contenu est inutilisable.
  static Carte? depuisJson(Object? json) {
    if (json is! Map) return null;
    int lire(String cle) {
      final v = json[cle];
      return v is int && v >= 0 ? v : 0;
    }

    final niveau = math.min(lire('n'), intervallesJours.length - 1);
    return Carte(niveau: niveau, prochaine: lire('p'), vus: lire('v'), justes: lire('j'));
  }
}
