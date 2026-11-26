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

/// Synonymes (syn), contraires (ant) et mots de la même famille (der). Paramètre : id du mot.
const String requeteRelations = '''
SELECT type, mot FROM relations
WHERE mot_id = ?
ORDER BY CASE type WHEN 'syn' THEN 0 WHEN 'ant' THEN 1 ELSE 2 END, rowid
''';

/// Verbes à particule d'un verbe (give → give up, give in). Paramètres : borne basse « give »
/// suivie d'une espace, borne haute « give » suivie de « ! » (texte plié), nombre maximal de lignes.
const String requeteVerbesAParticule = '''
SELECT mot FROM mots
WHERE nature = 'verb' AND mot_recherche > ? AND mot_recherche < ?
ORDER BY rang IS NULL, rang, mot
LIMIT ?
''';

/// Faux ami écrit à la main. Paramètre : mot anglais en minuscules.
const String requeteFauxAmi = '''
SELECT mot, piege, vrai FROM faux_amis WHERE mot = ?
''';

/// Mots anglais d'écriture proche (correction d'une faute de frappe). Paramètres : borne basse et
/// borne haute de la première lettre (texte plié), longueur minimale, longueur maximale, limite.
const String requeteMotsProchesAnglais = '''
SELECT mot, mot_recherche AS recherche, MIN(rang) AS rang FROM mots
WHERE mot_recherche >= ? AND mot_recherche < ? AND length(mot_recherche) BETWEEN ? AND ?
GROUP BY mot_recherche
ORDER BY rang IS NULL, rang
LIMIT ?
''';

/// Mêmes paramètres, pour les équivalents français.
const String requeteMotsProchesFrancais = '''
SELECT fr AS mot, fr_recherche AS recherche, NULL AS rang FROM traductions
WHERE fr_recherche >= ? AND fr_recherche < ? AND length(fr_recherche) BETWEEN ? AND ?
GROUP BY fr_recherche
LIMIT ?
''';

/// Recherche par motif (inter*, c?t). Paramètres : borne basse et haute du début fixe du motif,
/// motif GLOB, limite.
const String requeteMotsParMotif = '''
SELECT mot, MIN(rang) AS rang FROM mots
WHERE mot_recherche >= ? AND mot_recherche < ? AND mot_recherche GLOB ?
GROUP BY mot_recherche
ORDER BY rang IS NULL, rang, mot_recherche
LIMIT ?
''';

/// Recherche dans les définitions anglaises. Paramètres : trois motifs LIKE (« % » si inutilisé), limite.
const String requeteParDefinitionAnglaise = '''
SELECT m.id, m.mot, m.nature, m.rang, s.definition AS extrait
FROM sens s JOIN mots m ON m.id = s.mot_id
WHERE s.definition LIKE ? AND s.definition LIKE ? AND s.definition LIKE ?
ORDER BY m.rang IS NULL, m.rang, m.id
LIMIT ?
''';

/// Recherche dans les définitions françaises. Mêmes paramètres.
const String requeteParDefinitionFrancaise = '''
SELECT m.id, m.mot, m.nature, m.rang, d.texte AS extrait
FROM definitions_fr d JOIN mots m ON m.id = d.mot_id
WHERE d.texte LIKE ? AND d.texte LIKE ? AND d.texte LIKE ?
ORDER BY m.rang IS NULL, m.rang, m.id
LIMIT ?
''';

/// Équivalents français tirés au hasard (mauvaises réponses du quiz). Paramètre : nombre voulu.
const String requeteEquivalentsHasard = '''
SELECT t.fr FROM traductions t JOIN mots m ON m.id = t.mot_id
WHERE t.id >= (ABS(RANDOM()) % (SELECT MAX(id) FROM traductions)) + 1
  AND t.source = 'en+fr' AND length(t.fr) <= 25 AND t.fr NOT LIKE '% %'
  AND t.fr NOT GLOB '[A-Z]*' AND m.rang IS NOT NULL AND m.rang <= 10000 AND m.nature != 'name'
LIMIT ?
''';

/// Mots anglais courants tirés au hasard (mauvaises réponses du quiz inverse). Paramètre : nombre voulu.
const String requeteMotsHasard = '''
WITH d AS (SELECT (ABS(RANDOM()) % (SELECT MAX(id) FROM mots)) + 1 AS r)
SELECT mot FROM (
  SELECT mot, 0 AS tour, id FROM mots, d
  WHERE id >= d.r AND rang IS NOT NULL AND rang <= 10000 AND nature != 'name'
    AND mot NOT LIKE '% %' AND mot NOT GLOB '*[A-Z]*'
    AND EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = mots.id AND t.source = 'en+fr')
  UNION ALL
  SELECT mot, 1 AS tour, id FROM mots, d
  WHERE id < d.r AND rang IS NOT NULL AND rang <= 10000 AND nature != 'name'
    AND mot NOT LIKE '% %' AND mot NOT GLOB '*[A-Z]*'
    AND EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = mots.id AND t.source = 'en+fr')
)
ORDER BY tour, id
LIMIT ?
''';

/// Faux amis tirés au hasard (quiz). Paramètre : nombre voulu.
const String requeteFauxAmisHasard = '''
SELECT mot, piege, vrai FROM faux_amis ORDER BY RANDOM() LIMIT ?
''';

/// Ce qu'on sait d'une expression (type, niveau de langue, sens littéral…). Paramètre : id du mot.
const String requeteInfoExpression = '''
SELECT type, registre, litteral, fr, theme, exemple, curee FROM expressions WHERE mot_id = ?
''';

/// Liste d'expressions, les soignées d'abord. Paramètres : type (« » = tous) deux fois, thème (« » =
/// tous) deux fois, 1 pour afficher aussi le vulgaire, motif de recherche brut (« » = aucun) puis
/// « %motif% » deux fois (anglais, puis français), nombre de lignes, décalage.
const String requeteExpressions = '''
SELECT m.id, m.mot, m.nature, m.rang, e.type, e.registre, e.litteral, e.curee,
       CASE WHEN e.fr != '' THEN e.fr ELSE COALESCE((SELECT t.fr FROM traductions t WHERE t.mot_id = m.id
         ORDER BY CASE t.source WHEN 'en+fr' THEN 0 WHEN 'en' THEN 1 ELSE 2 END, t.id LIMIT 1), '') END AS fr
FROM expressions e JOIN mots m ON m.id = e.mot_id
WHERE (? = '' OR e.type = ?)
  AND (? = '' OR e.theme = ?)
  AND (? = 1 OR e.registre != 'vulgaire')
  AND (? = '' OR m.mot_recherche LIKE ?
       OR EXISTS (SELECT 1 FROM traductions t2 WHERE t2.mot_id = m.id AND t2.fr_recherche LIKE ?))
ORDER BY e.curee DESC,
         CASE e.type WHEN 'idiome' THEN 0 WHEN 'proverbe' THEN 1 WHEN 'utile' THEN 2 WHEN 'particule' THEN 3 ELSE 4 END,
         m.rang IS NULL, m.rang, m.mot_recherche
LIMIT ? OFFSET ?
''';

/// Expressions qui contiennent un mot (hors verbes à particule, déjà listés à part). Paramètres : mot
/// plié, le même mot (pour ne pas se renvoyer lui-même), 1 pour afficher aussi le vulgaire, limite.
const String requeteExpressionsAvec = '''
SELECT m.id, m.mot, m.nature, m.rang, e.type, e.registre, e.litteral, e.curee,
       CASE WHEN e.fr != '' THEN e.fr ELSE COALESCE((SELECT t.fr FROM traductions t WHERE t.mot_id = m.id
         ORDER BY CASE t.source WHEN 'en+fr' THEN 0 WHEN 'en' THEN 1 ELSE 2 END, t.id LIMIT 1), '') END AS fr
FROM expression_mots w
JOIN expressions e ON e.mot_id = w.expr_id
JOIN mots m ON m.id = e.mot_id
WHERE w.mot = ? AND m.mot_recherche != ? AND e.type != 'particule' AND (? = 1 OR e.registre != 'vulgaire')
ORDER BY e.curee DESC, m.rang IS NULL, m.rang, length(m.mot)
LIMIT ?
''';

/// Nombre d'expressions soignées qui conviennent à « l'expression du jour » (idiomes et proverbes).
const String requeteNombreExpressionsCurees = '''
SELECT COUNT(*) AS n FROM expressions
WHERE curee = 1 AND type IN ('idiome', 'proverbe') AND registre != 'vulgaire' AND fr != ''
''';

/// Une expression soignée, par numéro d'ordre. Paramètre : décalage.
const String requeteExpressionCuree = '''
SELECT m.id, m.mot, m.nature, m.rang, e.type, e.registre, e.litteral, e.curee, e.fr AS fr
FROM expressions e JOIN mots m ON m.id = e.mot_id
WHERE e.curee = 1 AND e.type IN ('idiome', 'proverbe') AND e.registre != 'vulgaire' AND e.fr != ''
ORDER BY e.mot_id
LIMIT 1 OFFSET ?
''';

/// Expressions soignées tirées au hasard (quiz). Paramètre : nombre voulu.
const String requeteExpressionsCureesHasard = '''
SELECT m.id, m.mot, m.nature, m.rang, e.type, e.registre, e.litteral, e.curee, e.fr AS fr
FROM expressions e JOIN mots m ON m.id = e.mot_id
WHERE e.curee = 1 AND e.type IN ('idiome', 'proverbe') AND e.registre != 'vulgaire' AND e.fr != ''
ORDER BY RANDOM()
LIMIT ?
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
