import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

List<String> lemmes(String mot) => candidatsLemmes(mot).map((c) => c.lemme).toList();

void main() {
  group('candidatsLemmes', () {
    test('pluriels et 3e personne', () {
      expect(lemmes('dogs'), contains('dog'));
      expect(lemmes('boxes'), contains('box'));
      expect(lemmes('flies'), contains('fly'));
      expect(lemmes('studies'), contains('study'));
      expect(lemmes('knives'), contains('knife'));
      expect(lemmes('goes'), contains('go'));
    });

    test('passé et participe passé', () {
      expect(lemmes('walked'), contains('walk'));
      expect(lemmes('loved'), contains('love'));
      expect(lemmes('stopped'), contains('stop'));
      expect(lemmes('studied'), contains('study'));
      expect(lemmes('picnicked'), contains('picnic'));
    });

    test('participe présent', () {
      expect(lemmes('walking'), contains('walk'));
      expect(lemmes('making'), contains('make'));
      expect(lemmes('running'), contains('run'));
      expect(lemmes('dying'), contains('die'));
    });

    test('comparatif, superlatif, adverbe', () {
      expect(lemmes('nicer'), contains('nice'));
      expect(lemmes('bigger'), contains('big'));
      expect(lemmes('happiest'), contains('happy'));
      expect(lemmes('quickly'), contains('quick'));
      expect(lemmes('happily'), contains('happy'));
    });

    test('mots trop courts ou étrangers à la règle', () {
      expect(lemmes('is'), isEmpty);
      expect(lemmes('d0gs'), isEmpty);
      expect(lemmes('abc'), isNot(contains('abc')));
    });

    test('les descriptions sont en français', () {
      expect(candidatsLemmes('walked').first.description, 'passé ou participe passé');
    });
  });

  group('sansPossessif', () {
    test('singulier et pluriel', () {
      expect(sansPossessif("world's"), 'world');
      expect(sansPossessif('dogs\''), 'dogs');
      expect(sansPossessif('world’s'), 'world');
    });

    test('pas un possessif', () {
      expect(sansPossessif('dog'), isNull);
      expect(sansPossessif("it's"), 'it'); // le moteur essaie « it », la contraction passe avant
      expect(sansPossessif("s'"), isNull);
    });
  });

  group('candidatsFrancais', () {
    List<String> fr(String m) => candidatsFrancais(m).map((c) => c.lemme).toList();

    test('pluriels', () {
      expect(fr('chiens'), contains('chien'));
      expect(fr('chevaux'), contains('cheval'));
      expect(fr('bateaux'), contains('bateau'));
    });

    test('féminins', () {
      expect(fr('petite'), contains('petit'));
      expect(fr('chanteuse'), contains('chanteur'));
      expect(fr('actrice'), contains('acteur'));
      expect(fr('sportive'), contains('sportif'));
    });
  });
}
