import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

void main() {
  test('distance d\'édition', () {
    expect(distanceEdition('world', 'world'), 0);
    expect(distanceEdition('wrld', 'world'), 1); // lettre manquante
    expect(distanceEdition('wolrd', 'world'), 1); // deux lettres inversées
    expect(distanceEdition('wordl', 'world'), 1);
    expect(distanceEdition('wurld', 'world'), 1); // lettre fausse
    expect(distanceEdition('worrld', 'world'), 1); // lettre en trop
    expect(distanceEdition('cat', 'dog'), 3);
    expect(distanceEdition('', 'abc'), 3);
  });

  test('tolérance selon la longueur', () {
    expect(toleranceFautes(3), 1);
    expect(toleranceFautes(4), 1);
    expect(toleranceFautes(5), 2);
  });
}
