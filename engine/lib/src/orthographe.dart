/// Distance entre deux mots, pour proposer une correction après une faute de frappe.
library;

import 'dart:math' as math;

/// Distance de Damerau-Levenshtein (version « chaîne optimale ») : nombre minimal d'insertions,
/// suppressions, remplacements et permutations de deux lettres voisines.
int distanceEdition(String a, String b) {
  if (a == b) return 0;
  final n = a.length;
  final m = b.length;
  if (n == 0) return m;
  if (m == 0) return n;
  var avantAvant = List<int>.filled(m + 1, 0);
  var avant = List<int>.generate(m + 1, (j) => j);
  for (var i = 1; i <= n; i++) {
    final courant = List<int>.filled(m + 1, 0);
    courant[0] = i;
    for (var j = 1; j <= m; j++) {
      final cout = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = math.min(math.min(avant[j] + 1, courant[j - 1] + 1), avant[j - 1] + cout);
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        v = math.min(v, avantAvant[j - 2] + 1);
      }
      courant[j] = v;
    }
    avantAvant = avant;
    avant = courant;
  }
  return avant[m];
}

/// Nombre de fautes tolérées pour un mot de [longueur] lettres.
int toleranceFautes(int longueur) => longueur <= 4 ? 1 : 2;
