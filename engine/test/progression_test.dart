import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

void main() {
  test('série en cours', () {
    expect(serieEnCours([], 100), 0);
    expect(serieEnCours([100], 100), 1);
    expect(serieEnCours([98, 99, 100], 100), 3);
    // pas encore révisé aujourd'hui : la série d'hier continue
    expect(serieEnCours([97, 98, 99], 100), 3);
    // un jour manqué casse la série
    expect(serieEnCours([96, 97, 98], 100), 0);
    expect(serieEnCours([95, 96, 98, 99, 100], 100), 3);
    expect(serieEnCours([100, 100, 99], 100), 2); // doublons ignorés
  });

  test('meilleure série', () {
    expect(meilleureSerie([]), 0);
    expect(meilleureSerie([5]), 1);
    expect(meilleureSerie([1, 2, 3, 10, 11]), 3);
    expect(meilleureSerie([11, 10, 3, 2, 1, 1]), 3);
  });

  test('taux de réussite et mots difficiles', () {
    expect(tauxReussite(const Carte()), isNull);
    expect(tauxReussite(const Carte(vus: 4, justes: 3)), 0.75);
    expect(estDifficile(const Carte(vus: 2, justes: 0)), isFalse); // trop tôt pour juger
    expect(estDifficile(const Carte(vus: 3, justes: 1)), isTrue);
    expect(estDifficile(const Carte(vus: 5, justes: 3)), isFalse); // exactement 60 % : pas difficile
    const cartes = {
      'a': Carte(vus: 4, justes: 2),
      'b': Carte(vus: 5, justes: 1),
      'c': Carte(vus: 10, justes: 9),
      'd': Carte(vus: 3, justes: 1),
    };
    expect(motsDifficiles(cartes, ['a', 'b', 'c', 'd', 'inconnu']), ['b', 'd', 'a']);
  });
}
