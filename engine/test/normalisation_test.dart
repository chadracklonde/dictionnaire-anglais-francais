import 'dart:io';

import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

void main() {
  test('plier suit les cas partagés avec Python (test/pliage.tsv)', () {
    final lignes = File('test/pliage.tsv').readAsLinesSync();
    var verifies = 0;
    for (final ligne in lignes) {
      if (ligne.startsWith('#') || ligne.trim().isEmpty) continue;
      final colonnes = ligne.split('\t');
      expect(colonnes.length, 2, reason: ligne);
      expect(plier(colonnes[0]), colonnes[1], reason: 'plier(${colonnes[0]})');
      verifies++;
    }
    expect(verifies, greaterThan(10));
  });

  test('normaliser garde les accents mais pas la casse', () {
    expect(normaliser('  Été   Chaud '), 'été chaud');
    expect(normaliser('DON’T'), "don't");
    expect(normaliser('Straße'), 'strasse');
  });

  test('plier retire les accents combinants', () {
    expect(plier('café'), 'cafe');
  });
}
