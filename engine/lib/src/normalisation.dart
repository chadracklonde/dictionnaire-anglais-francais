/// Normalisation des textes. Doit rester d'accord avec `norm` et `fold` de tools/construire_base.py
/// (le fichier engine/test/pliage.tsv est vérifié par les tests Python ET Dart).
library;

// Lettres accentuées → lettre de base. Les lettres que la décomposition Unicode (NFKD) ne
// décompose pas (ł, ø, đ, ħ, ŧ, ı) restent telles quelles, comme côté Python.
const Map<String, String> _groupes = {
  'a': 'àáâãäåāăą',
  'c': 'çćĉċč',
  'd': 'ď',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥ',
  'i': 'ìíîïĩīĭį',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľ',
  'n': 'ñńņň',
  'o': 'òóôõöōŏő',
  'r': 'ŕŗř',
  's': 'śŝşš',
  't': 'ţť',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final Map<String, String> _table = _construireTable();

Map<String, String> _construireTable() {
  final table = <String, String>{};
  _groupes.forEach((base, lettres) {
    for (final rune in lettres.runes) {
      table[String.fromCharCode(rune)] = base;
    }
  });
  table['œ'] = 'oe';
  table['æ'] = 'ae';
  table['ß'] = 'ss';
  table['’'] = "'";
  table['‘'] = "'";
  return table;
}

String _espaces(String texte) =>
    texte.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).join(' ');

/// Forme de comparaison : minuscules, espaces normalisés, apostrophe droite, accents conservés.
String normaliser(String texte) {
  return _espaces(texte)
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('ß', 'ss');
}

/// Forme de recherche : sans accents ni majuscules (café → cafe, Œuf → oeuf).
String plier(String texte) {
  final bas = _espaces(texte).toLowerCase();
  final sortie = StringBuffer();
  for (final rune in bas.runes) {
    if (rune >= 0x0300 && rune <= 0x036F) continue; // accents combinants (texte décomposé)
    final lettre = String.fromCharCode(rune);
    sortie.write(_table[lettre] ?? lettre);
  }
  return sortie.toString();
}
