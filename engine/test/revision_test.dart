import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

void main() {
  test('une carte neuve est à réviser aujourd\'hui', () {
    const c = Carte();
    expect(c.estDue(20000), isTrue);
    expect(c.niveau, 0);
    expect(c.maitrisee, isFalse);
  });

  test('une bonne réponse monte d\'une boîte et espace la révision', () {
    var c = const Carte();
    c = c.apresReponse(true, 100);
    expect((c.niveau, c.prochaine), (1, 101));
    c = c.apresReponse(true, 101);
    expect((c.niveau, c.prochaine), (2, 103));
    c = c.apresReponse(true, 103);
    expect((c.niveau, c.prochaine), (3, 107));
    expect(c.estDue(106), isFalse);
    expect(c.estDue(107), isTrue);
    expect((c.vus, c.justes), (3, 3));
  });

  test('une erreur ramène à la première boîte, à réviser tout de suite', () {
    final c = const Carte(niveau: 4, prochaine: 200, vus: 4, justes: 4).apresReponse(false, 150);
    expect((c.niveau, c.prochaine), (0, 150));
    expect((c.vus, c.justes), (5, 4));
    expect(c.estDue(150), isTrue);
  });

  test('la dernière boîte est plafonnée et la carte est alors maîtrisée', () {
    var c = const Carte();
    for (var i = 0; i < 20; i++) {
      c = c.apresReponse(true, 1000 + i);
    }
    expect(c.niveau, intervallesJours.length - 1);
    expect(c.maitrisee, isTrue);
  });

  test('enregistrement et relecture', () {
    const c = Carte(niveau: 3, prochaine: 123, vus: 7, justes: 5);
    final relue = Carte.depuisJson(c.versJson())!;
    expect((relue.niveau, relue.prochaine, relue.vus, relue.justes), (3, 123, 7, 5));
    expect(Carte.depuisJson('texte'), isNull);
    expect(Carte.depuisJson({'n': 99, 'p': -4})!.niveau, intervallesJours.length - 1);
    expect(Carte.depuisJson({'n': 99, 'p': -4})!.prochaine, 0);
  });

  test('numéro de jour', () {
    expect(numeroDeJour(DateTime(1970, 1, 1)), 0);
    expect(numeroDeJour(DateTime(1970, 1, 2, 23, 59)), 1);
    expect(numeroDeJour(DateTime(2026, 11, 26)) - numeroDeJour(DateTime(2026, 11, 25)), 1);
  });
}
