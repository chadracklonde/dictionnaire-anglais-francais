/// Suivi de la progression : série de jours, taux de réussite, mots difficiles.
library;

import 'revision.dart';

/// Jours de suite où l'on a révisé, en comptant jusqu'à [aujourdhui]. Si l'on n'a pas encore
/// révisé aujourd'hui, la série d'hier reste en cours (elle ne s'interrompt qu'à la fin de la journée).
int serieEnCours(Iterable<int> jours, int aujourdhui) {
  final actifs = jours.toSet();
  var jour = actifs.contains(aujourdhui) ? aujourdhui : aujourdhui - 1;
  var n = 0;
  while (actifs.contains(jour)) {
    n++;
    jour--;
  }
  return n;
}

/// La plus longue série de jours consécutifs.
int meilleureSerie(Iterable<int> jours) {
  final tries = jours.toSet().toList()..sort();
  var meilleure = 0;
  var courante = 0;
  int? precedent;
  for (final j in tries) {
    courante = precedent != null && j == precedent + 1 ? courante + 1 : 1;
    if (courante > meilleure) meilleure = courante;
    precedent = j;
  }
  return meilleure;
}

/// Part de bonnes réponses d'une carte (0 à 1), ou null si elle n'a jamais été vue.
double? tauxReussite(Carte carte) => carte.vus == 0 ? null : carte.justes / carte.vus;

/// Un mot est difficile après au moins trois réponses dont moins de 60 % de bonnes.
bool estDifficile(Carte carte) => carte.vus >= 3 && carte.justes / carte.vus < 0.6;

/// Les clés des mots difficiles parmi [cartes], les plus ratés d'abord.
List<String> motsDifficiles(Map<String, Carte> cartes, Iterable<String> cles) {
  final difficiles = [
    for (final c in cles)
      if (cartes[c] != null && estDifficile(cartes[c]!)) c
  ];
  difficiles.sort((a, b) {
    final d = tauxReussite(cartes[a]!)!.compareTo(tauxReussite(cartes[b]!)!);
    return d != 0 ? d : cartes[b]!.vus.compareTo(cartes[a]!.vus);
  });
  return difficiles;
}
