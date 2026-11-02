import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

import 'source_memoire.dart';

void main() {
  final moteur = Moteur(SourceMemoire());

  test('mot direct', () async {
    final r = await moteur.chercher('Hello');
    expect(r.fiches.single.mot.mot, 'hello');
    expect(r.fiches.single.equivalents.single.fr, 'bonjour');
    expect(r.directionParDefaut, Direction.anglaisFrancais);
    expect(r.regleAnglais, isNull);
  });

  test('plusieurs natures : celle qui a des équivalents d\'abord, dans l\'ordre de fréquence', () async {
    final r = await moteur.chercher('go');
    expect(r.fiches.map((f) => f.mot.id), [1, 2]);
  });

  test('forme fléchie connue de la base (went → go)', () async {
    final r = await moteur.chercher('went');
    expect(r.fiches.single.mot.mot, 'go');
    expect(r.fiches.single.formeDemandee, 'went');
    expect(r.fiches.single.etiquetteRenvoi, 'past');
    expect(r.regleAnglais, isNull);
  });

  test('un mot sans équivalent passe après son mot de base (turned → turn)', () async {
    final r = await moteur.chercher('turned');
    expect(r.fiches.first.mot.mot, 'turn');
    expect(r.fiches.map((f) => f.mot.mot), contains('turned'));
  });

  test('pluriel régulier par règle', () async {
    final r = await moteur.chercher('Dogs');
    expect(r.fiches.first.mot.mot, 'dog');
    expect(r.regleAnglais, contains('dog'));
    expect(r.regleAnglais, contains('pluriel'));
  });

  test('possessif', () async {
    final r = await moteur.chercher('world’s');
    expect(r.fiches.first.mot.mot, 'world');
    expect(r.regleAnglais, 'possessif de « world »');
  });

  test('possessif d\'un pluriel régulier', () async {
    final r = await moteur.chercher("dogs'");
    expect(r.fiches.first.mot.mot, 'dog');
    expect(r.regleAnglais, isNotNull);
  });

  test('contraction écrite à la main', () async {
    final r = await moteur.chercher("can't");
    expect(r.contraction?.developpe, 'cannot');
    expect(r.vide, isFalse);
    expect(r.fiches, isEmpty);
    expect(r.suggestions, isEmpty);
  });

  test('français → anglais', () async {
    final r = await moteur.chercher('Chien');
    expect(r.inverses.single.mot.mot, 'dog');
    expect(r.inverses.single.confirme, isTrue);
    expect(r.directionParDefaut, Direction.francaisAnglais);
    expect(r.regleFrancais, isNull);
  });

  test('français → anglais, pluriel par règle', () async {
    final r = await moteur.chercher('chiens');
    expect(r.inverses.single.mot.mot, 'dog');
    expect(r.regleFrancais, contains('chien'));
  });

  test('mot présent dans les deux langues : les deux sens sont remplis', () async {
    final r = await moteur.chercher('bonjour');
    expect(r.inverses, isNotEmpty);
    expect(r.fiches, isEmpty);
  });

  test('rien trouvé : suggestions par début de mot', () async {
    final r = await moteur.chercher('wor');
    expect(r.vide, isTrue);
    expect(r.suggestions, contains('world'));
  });

  test('requête vide', () async {
    final r = await moteur.chercher('   ');
    expect(r.vide, isTrue);
    expect(r.suggestions, isEmpty);
  });

  test('suggestions pendant la frappe : anglais puis français', () async {
    expect(await moteur.suggerer('wo'), ['world']);
    expect(await moteur.suggerer('b'), isEmpty); // un seul caractère : trop court
    expect(await moteur.suggerer('bo'), ['bonjour']);
  });

  test('conjugaison d\'un mot avec les formes de la base', () async {
    final c = await moteur.conjuguerMot(SourceMemoire.motGoV);
    expect(c.formes.passe, 'went');
    expect(c.groupes.first.temps.first.lignes[2].texte, 'he / she / it goes');
  });
}
