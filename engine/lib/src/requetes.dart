/// Requêtes SQL du moteur. Chaque constante est vérifiée contre une vraie base par
/// tools/test_requetes.py : garder une constante `const String` par bloc de texte triple,
/// des `?` positionnels et aucun dollar dans le SQL.
library;

/// Mots dont la forme de recherche (sans accents) est exactement le texte. Paramètre : texte plié.
const String requeteMotsParRecherche = '''
SELECT id, mot, nature, rang FROM mots
WHERE mot_recherche = ?
ORDER BY rang IS NULL, rang, id
LIMIT 12
''';

/// Mots de base d'une forme (went → go), de même nature que la forme s'il y en a. Paramètre : forme normalisée.
const String requeteLemmesDeForme = '''
SELECT m.id, m.mot, m.nature, m.rang, r.etiquettes
FROM renvois r JOIN mots m ON m.mot_norm = r.lemme_norm
  AND (m.nature = r.nature OR NOT EXISTS
       (SELECT 1 FROM mots m2 WHERE m2.mot_norm = r.lemme_norm AND m2.nature = r.nature))
WHERE r.forme_norm = ?
ORDER BY (m.nature = r.nature) DESC, m.rang IS NULL, m.rang, m.id
LIMIT 12
''';

/// Contraction écrite à la main. Paramètre : forme normalisée.
const String requeteContraction = '''
SELECT forme, developpe, traduction FROM contractions WHERE forme = ?
''';

/// Équivalents français d'un mot, les mieux confirmés d'abord. Paramètre : id du mot.
const String requeteEquivalents = '''
SELECT fr, etiquette, genre, source FROM traductions
WHERE mot_id = ?
ORDER BY CASE source WHEN 'en+fr' THEN 0 WHEN 'en' THEN 1 ELSE 2 END, id
''';

const String requeteSens = '''
SELECT ordre, definition, contexte, etiquettes, exemple FROM sens
WHERE mot_id = ?
ORDER BY ordre
''';

const String requeteDefinitionsFr = '''
SELECT texte FROM definitions_fr WHERE mot_id = ? ORDER BY ordre
''';

const String requeteFormes = '''
SELECT forme, etiquettes FROM formes WHERE mot_id = ? ORDER BY id
''';

const String requeteAudio = '''
SELECT fichier, accent FROM audio
WHERE mot_id = ?
ORDER BY CASE accent WHEN 'us' THEN 0 WHEN 'uk' THEN 1 WHEN 'au' THEN 2 ELSE 3 END, id
''';

const String requetePrononciations = '''
SELECT accent, api FROM prononciations
WHERE mot_id = ?
ORDER BY CASE accent WHEN 'us' THEN 0 WHEN 'uk' THEN 1 ELSE 2 END, id
''';

/// Français → anglais. Paramètres : texte plié, nombre maximal de lignes.
const String requeteAnglaisParFrancais = '''
SELECT m.id, m.mot, m.nature, m.rang, t.fr, t.etiquette, t.genre, t.source
FROM traductions t JOIN mots m ON m.id = t.mot_id
WHERE t.fr_recherche = ?
ORDER BY CASE t.source WHEN 'en+fr' THEN 0 WHEN 'en' THEN 1 ELSE 2 END, m.rang IS NULL, m.rang, m.id
LIMIT ?
''';

/// Suggestions anglaises par début de mot. Paramètres : préfixe plié, borne supérieure, limite.
const String requeteSuggestionsAnglais = '''
SELECT COALESCE(MIN(CASE WHEN mot = mot_norm THEN mot END), MIN(mot)) AS mot
FROM mots
WHERE mot_recherche >= ? AND mot_recherche < ?
GROUP BY mot_recherche
ORDER BY MIN(COALESCE(rang, 1000000)), mot_recherche
LIMIT ?
''';

/// Suggestions françaises par début de mot. Mêmes paramètres.
const String requeteSuggestionsFrancais = '''
SELECT COALESCE(MIN(CASE WHEN fr = fr_norm THEN fr END), MIN(fr)) AS fr
FROM traductions
WHERE fr_recherche >= ? AND fr_recherche < ?
GROUP BY fr_recherche
ORDER BY COUNT(*) DESC, fr_recherche
LIMIT ?
''';

/// Index alphabétique anglais, page suivante après [cle]. Paramètres : clé de recherche précédente, limite.
const String requeteIndexAnglais = '''
SELECT COALESCE(MIN(CASE WHEN mot = mot_norm THEN mot END), MIN(mot)) AS mot, mot_recherche AS cle
FROM mots
WHERE mot_recherche > ?
GROUP BY mot_recherche
ORDER BY mot_recherche
LIMIT ?
''';

/// Chiffres de la base (écran « À propos »).
const String requeteChiffres = '''
SELECT (SELECT COUNT(*) FROM mots) AS mots,
       (SELECT COUNT(*) FROM traductions) AS traductions,
       (SELECT COUNT(*) FROM mots WHERE nature = 'verb') AS verbes,
       (SELECT COUNT(*) FROM audio) AS audio
''';

/// Métadonnées de la base (date de construction, licence…).
const String requeteMeta = '''
SELECT cle, valeur FROM meta
''';
