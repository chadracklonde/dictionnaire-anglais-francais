#!/usr/bin/env python3
"""Phase 1 : construit la base SQLite du dictionnaire à partir des deux éditions du Wiktionnaire.

Sous-commandes (dans cet ordre) :

  lire --edition en   < raw-wiktextract-data.jsonl   mots, sens, traductions, formes, audio
  lire --edition fr   < fr-extract.jsonl             définitions françaises, traductions inversées
  finaliser                                           contractions, fréquence, élagage, index
  rapport                                             rapport de qualité (annotation RAPPORT-BASE)

L'édition anglaise doit être lue avant l'édition française : les traductions inversées
(français -> anglais) sont rattachées aux mots anglais déjà présents.

Exemple :
  curl -sSL URL_EN | gunzip -c | python3 -I tools/construire_base.py lire --db base.db --edition en
  curl -sSL URL_FR | gunzip -c | python3 -I tools/construire_base.py lire --db base.db --edition fr
  python3 -I tools/construire_base.py finaliser --db base.db --frequence frequence.txt
  python3 -I tools/construire_base.py rapport --db base.db --frequence frequence.txt --out resultats

Ce script est autonome : il n'importe aucun autre module du dépôt (lancé avec -I, le dossier
du script n'est pas dans le chemin d'import).
"""
import argparse
import collections
import datetime
import glob
import gzip
import json
import os
import re
import sqlite3
import sys
import unicodedata

try:  # orjson est bien plus rapide ; le module standard suffit pour les tests
    import orjson

    loads = orjson.loads
except ImportError:  # pragma: no cover
    loads = json.loads

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(HERE, "schema.sql")
CONTRACTIONS = os.path.join(HERE, "data", "contractions.tsv")
FAUX_AMIS = os.path.join(HERE, "data", "faux_amis.tsv")
EXPRESSIONS = os.path.join(HERE, "data", "expressions_*.tsv")
VERSION_SCHEMA = "1"

MAX_SENS = 8          # définitions anglaises gardées par mot
MAX_DEF_FR = 6        # définitions françaises gardées par mot
MAX_FORMES = 20       # formes fléchies gardées par mot
MAX_RELATIONS = {"syn": 10, "ant": 8, "der": 8}  # mots liés gardés par mot et par type
MAX_AUDIO = 12        # enregistrements gardés par entrée
MAX_API = 8           # transcriptions gardées par entrée
SEUIL_RANG_DEFAUT = 30000
SEUILS_COUVERTURE = (1000, 5000, 10000, 20000)
SEUIL_BLOQUANT = 95.0  # % minimum de mots courants (5000 premiers) avec un équivalent

# Accents : une enregistrement est classé d'après ses balises, sinon d'après son nom de fichier.
US_TAGS = {"us", "general-american", "american", "general american", "californian",
           "midwest", "new york city"}
UK_TAGS = {"uk", "received-pronunciation", "received pronunciation", "rp", "british",
           "southern-england", "southern england", "england", "london", "cockney",
           "british english", "standard southern british"}
AU_TAGS = {"australia", "australian", "new-zealand", "new zealand"}
PREFIXES_FICHIER = (("en-us", "us"), ("en-uk", "uk"), ("en-gb", "uk"), ("en-au", "au"))

NATURES_IGNOREES = {"character", "punct"}
NATURES = {
    "adjective": "adj", "adverb": "adv", "preposition": "prep", "conjunction": "conj",
    "interjection": "intj", "pronoun": "pron", "determiner": "det", "numeral": "num",
    "proper noun": "name", "proper-noun": "name", "noun": "noun", "verb": "verb",
    # noms français du Wiktionnaire français
    "nom": "noun", "nom commun": "noun", "verbe": "verb", "adjectif": "adj",
    "adverbe": "adv", "préposition": "prep", "conjonction": "conj", "pronom": "pron",
    "déterminant": "det", "nom propre": "name", "locution": "phrase",
}
IGNORER_FORMES = {"table-tags", "inflection-template", "class", "romanization"}

# « past tense of can », « plural of tooth »… dans une définition ou son contexte.
PATRON_RENVOI = re.compile(r"^(?P<et>[a-z][a-z ,'\-]{1,80}?) of (?P<lemme>[a-z][^,;:()]{0,60})$", re.I)
MOTS_GRAMMAIRE = ("tense", "participle", "plural", "singular", "comparative", "superlative",
                  "conditional", "gerund", "subjunctive", "indicative", "imperative", "possessive",
                  "inflection", "contraction")


# ---------------------------------------------------------------- texte

_PLIAGE = str.maketrans({"’": "'", "‘": "'", "œ": "oe", "æ": "ae"})


def norm(text):
    """Forme de comparaison : NFC, sans espaces autour, sans casse, apostrophe droite."""
    return unicodedata.normalize("NFC", str(text)).strip().casefold().replace("’", "'")


def fold(text):
    """Forme de recherche : sans accents ni casse (café -> cafe, Œuf -> oeuf)."""
    t = unicodedata.normalize("NFKD", str(text).casefold().translate(_PLIAGE))
    return "".join(ch for ch in t if not unicodedata.combining(ch)).strip()


def clip(text, limit):
    """Espaces normalisés et longueur bornée."""
    return " ".join(str(text).split())[:limit]


def normaliser_nature(pos):
    pos = norm(pos) if pos else ""
    return NATURES.get(pos, pos) or "?"


def accent_group(tags, filename):
    """us / uk / au / autre, d'après les balises (en minuscules) puis le nom de fichier."""
    tags = set(tags)
    if tags & US_TAGS:
        return "us"
    if tags & UK_TAGS:
        return "uk"
    if tags & AU_TAGS:
        return "au"
    low = (filename or "").casefold()
    for prefix, group in PREFIXES_FICHIER:
        if low.startswith(prefix):
            return group
    return "autre"


def audio_of(sound):
    """Nom de fichier audio d'un bloc `sounds`, ou None."""
    name = sound.get("audio")
    if name:
        return str(name)
    for key in ("ogg_url", "mp3_url", "opus_url", "flac_url", "wav_url"):
        url = sound.get(key)
        if url:
            return str(url).rsplit("/", 1)[-1]
    return None


def translations_to(entry, code):
    """Traductions vers la langue `code` (`lang_code` pour wiktextract récent, `code` pour l'ancien)."""
    return [t for t in (entry.get("translations") or [])
            if isinstance(t, dict) and (t.get("lang_code") or t.get("code")) == code and t.get("word")]


def _est_renvoi(sense):
    return bool(sense.get("form_of") or sense.get("alt_of"))


def _tags(sense, limit=4):
    kept = [str(t) for t in (sense.get("tags") or []) if t not in ("form-of", "alt-of")]
    return ", ".join(kept[:limit])


# ---------------------------------------------------------------- base

def ouvrir(path):
    """Ouvre la base (la crée avec le schéma si besoin), réglée pour un import rapide."""
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA journal_mode = OFF")
    conn.execute("PRAGMA synchronous = OFF")
    conn.execute("PRAGMA temp_store = MEMORY")
    with open(SCHEMA, encoding="utf-8") as f:
        conn.executescript(f.read())
    return conn


def trouver_ou_creer(cur, word, pos, source, souple=False):
    """Identifiant du mot (graphie, nature). `souple` : tolère une autre casse, et toute nature si inconnue."""
    word = clip(word, 100)
    row = cur.execute("SELECT id FROM mots WHERE mot = ? AND nature = ?", (word, pos)).fetchone()
    if row is None and souple:
        row = cur.execute("SELECT id FROM mots WHERE mot_norm = ? AND nature = ? ORDER BY id LIMIT 1",
                          (norm(word), pos)).fetchone()
        if row is None and pos == "?":
            row = cur.execute("SELECT id FROM mots WHERE mot_norm = ? ORDER BY id LIMIT 1",
                              (norm(word),)).fetchone()
    col = "src_" + source  # source vaut 'en' ou 'fr' : jamais de texte libre
    if row is not None:
        cur.execute("UPDATE mots SET %s = 1 WHERE id = ? AND %s = 0" % (col, col), (row[0],))
        return row[0]
    cur.execute(
        "INSERT INTO mots(mot, mot_norm, mot_recherche, nature, %s) VALUES (?, ?, ?, ?, 1)" % col,
        (word, norm(word), fold(word), pos))
    return cur.lastrowid


def ajouter_sens(cur, mot_id, senses):
    n = cur.execute("SELECT COUNT(*) FROM sens WHERE mot_id = ?", (mot_id,)).fetchone()[0]
    for s in senses:
        if n >= MAX_SENS:
            break
        glosses = s.get("glosses") or []
        if _est_renvoi(s) or not glosses:
            continue
        definition = clip(glosses[-1], 300)
        if not definition:
            continue
        contexte = clip(glosses[0], 120) if len(glosses) > 1 else ""
        exemple = ""
        for x in s.get("examples") or []:
            if isinstance(x, dict) and x.get("text"):
                exemple = clip(x["text"], 200)
                break
        n += 1
        cur.execute(
            "INSERT INTO sens(mot_id, ordre, definition, contexte, etiquettes, exemple) "
            "VALUES (?, ?, ?, ?, ?, ?)", (mot_id, n, definition, contexte, _tags(s), exemple))


def ajouter_definitions_fr(cur, mot_id, senses):
    n = cur.execute("SELECT COUNT(*) FROM definitions_fr WHERE mot_id = ?", (mot_id,)).fetchone()[0]
    for s in senses:
        if n >= MAX_DEF_FR:
            break
        glosses = s.get("glosses") or []
        if _est_renvoi(s) or not glosses:
            continue
        texte = clip(glosses[-1], 300)
        if not texte:
            continue
        cur.execute("INSERT OR IGNORE INTO definitions_fr(mot_id, ordre, texte) VALUES (?, ?, ?)",
                    (mot_id, n + 1, texte))
        if cur.rowcount:
            n += 1


def _genre(trad):
    tags = {str(t).casefold() for t in trad.get("tags") or []}
    m, f = "masculine" in tags, "feminine" in tags
    return "mf" if (m and f) else "m" if m else "f" if f else ""


def ajouter_traduction(cur, mot_id, fr, etiquette, source, genre=""):
    """Ajoute un équivalent français ; renvoie False si le texte est inutilisable."""
    fr = clip(fr, 80)
    if not fr or "http" in fr:
        return False
    cur.execute(
        "INSERT INTO traductions(mot_id, fr, fr_norm, fr_recherche, etiquette, genre, source) "
        "VALUES (?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(mot_id, fr_norm) DO UPDATE SET "
        "source = CASE WHEN source = excluded.source THEN source ELSE 'en+fr' END, "
        "etiquette = CASE WHEN etiquette = '' THEN excluded.etiquette ELSE etiquette END, "
        "genre = CASE WHEN genre = '' THEN excluded.genre ELSE genre END",
        (mot_id, fr, norm(fr), fold(fr), clip(etiquette, 80), genre, source))
    return True


def ajouter_formes(cur, mot_id, word, entry):
    n = 0
    base = norm(word)
    for f in entry.get("forms") or []:
        form, tags = f.get("form"), [str(t) for t in f.get("tags") or []]
        if not form or form in ("-", "no-table-tags") or set(tags) & IGNORER_FORMES:
            continue
        if norm(form) == base:
            continue
        cur.execute("INSERT OR IGNORE INTO formes(mot_id, forme, etiquettes) VALUES (?, ?, ?)",
                    (mot_id, clip(form, 60), ",".join(tags)[:80]))
        n += 1
        if n >= MAX_FORMES:
            break


def ajouter_relations(cur, mot_id, word, entry):
    """Synonymes, contraires et dérivés, en tête d'entrée comme dans les sens. Renvoie leur nombre."""
    total = 0
    base = norm(word)
    sources = [entry] + [s for s in entry.get("senses") or [] if isinstance(s, dict)]
    for type_, cle in (("syn", "synonyms"), ("ant", "antonyms"), ("der", "derived")):
        n = 0
        for src in sources:
            for item in src.get(cle) or []:
                texte = item.get("word") if isinstance(item, dict) else item
                if not texte or n >= MAX_RELATIONS[type_]:
                    continue
                texte = clip(texte, 60)
                if not texte or "http" in texte or norm(texte) == base:
                    continue
                cur.execute("INSERT OR IGNORE INTO relations(mot_id, type, mot) VALUES (?, ?, ?)",
                            (mot_id, type_, texte))
                n += cur.rowcount
        total += n
    return total


def ajouter_sons(cur, mot_id, entry):
    n_audio = n_api = 0
    for s in entry.get("sounds") or []:
        tags = {str(t).casefold() for t in s.get("tags") or []}
        name = audio_of(s)
        group = accent_group(tags, name)
        if name and n_audio < MAX_AUDIO:
            cur.execute("INSERT OR IGNORE INTO audio(mot_id, fichier, accent) VALUES (?, ?, ?)",
                        (mot_id, clip(name, 200), group))
            n_audio += 1
        ipa = s.get("ipa")
        if ipa and n_api < MAX_API:
            cur.execute("INSERT OR IGNORE INTO prononciations(mot_id, accent, api) VALUES (?, ?, ?)",
                        (mot_id, group, clip(ipa, 80)))
            n_api += 1


def ajouter_renvois(cur, word, pos, senses):
    """Enregistre les renvois « forme de » ; renvoie leur nombre."""
    n = 0
    for s in senses:
        etiq = _tags(s)
        for key in ("form_of", "alt_of"):
            for target in s.get(key) or []:
                lemme = target.get("word") if isinstance(target, dict) else target
                if not lemme or norm(lemme) == norm(word):
                    continue
                cur.execute(
                    "INSERT OR IGNORE INTO renvois(forme, forme_norm, nature, lemme_norm, etiquettes) "
                    "VALUES (?, ?, ?, ?, ?)", (clip(word, 100), norm(word), pos, norm(lemme), etiq))
                n += cur.rowcount
    return n


# ---------------------------------------------------------------- lecture

def _entree_anglaise(cur, e, edition, c):
    word = clip(e["word"], 100)
    pos = normaliser_nature(e.get("pos"))
    if not word or pos in NATURES_IGNOREES:
        return
    senses = [s for s in (e.get("senses") or []) if isinstance(s, dict)]
    if senses and all(_est_renvoi(s) for s in senses):
        c["renvois"] += ajouter_renvois(cur, word, pos, senses)
        return
    trs = translations_to(e, "fr") if edition == "en" else []
    if not trs and not any(s.get("glosses") and not _est_renvoi(s) for s in senses):
        c["ignorees_sans_contenu"] += 1
        return
    c["entrees_anglaises"] += 1
    mot_id = trouver_ou_creer(cur, word, pos, edition, souple=(edition == "fr"))
    if edition == "en":
        ajouter_sens(cur, mot_id, senses)
        for t in trs:
            if ajouter_traduction(cur, mot_id, t["word"], t.get("sense") or "", "en", _genre(t)):
                c["traductions_en"] += 1
        ajouter_formes(cur, mot_id, word, e)
        c["relations"] += ajouter_relations(cur, mot_id, word, e)
    else:
        ajouter_definitions_fr(cur, mot_id, senses)
    ajouter_sons(cur, mot_id, e)


def _entree_francaise(cur, e, c):
    word = clip(e["word"], 80)
    pos = normaliser_nature(e.get("pos"))
    trs = translations_to(e, "en")
    if not word or not trs or pos in NATURES_IGNOREES:
        return
    c["francais_avec_traduction"] += 1
    for t in trs:
        en = clip(t["word"], 100)
        if not en:
            continue
        mot_id = trouver_ou_creer(cur, en, pos, "fr", souple=True)
        if ajouter_traduction(cur, mot_id, word, t.get("sense") or "", "fr"):
            c["traductions_inversees"] += 1


def lire(conn, lines, edition, limit=None, lot=50000):
    """Lit un flux JSONL kaikki. Renvoie un compteur de ce qui a été retenu."""
    if edition not in ("en", "fr"):
        raise ValueError("édition inconnue : %r" % edition)
    c = collections.Counter()
    cur = conn.cursor()
    for raw in lines:
        if limit is not None and c["lignes"] >= limit:
            break
        raw = raw.strip()
        if not raw:
            continue
        c["lignes"] += 1
        try:
            e = loads(raw)
        except ValueError:
            c["illisibles"] += 1
            continue
        if not isinstance(e, dict) or not isinstance(e.get("word"), str) or not e["word"].strip():
            continue
        lang = e.get("lang_code")
        if lang == "en":
            _entree_anglaise(cur, e, edition, c)
        elif lang == "fr" and edition == "fr":
            _entree_francaise(cur, e, c)
        if c["lignes"] % lot == 0:
            conn.commit()
    conn.commit()
    return c


# ---------------------------------------------------------------- finalisation

def charger_frequence(path):
    """Liste de mots, un par ligne, du plus au moins fréquent -> {mot_norm: rang}."""
    ranks = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            w = norm(line)
            if w and w not in ranks:
                ranks[w] = len(ranks) + 1
    return ranks


def charger_contractions(conn, path):
    """Table écrite à la main : forme <TAB> développement <TAB> traduction. Renvoie le nombre de lignes."""
    n = 0
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            cols = [col.strip() for col in line.split("\t")]
            if len(cols) < 3 or not all(cols[:3]):
                raise ValueError("%s ligne %d : trois colonnes attendues" % (path, number))
            conn.execute("INSERT OR REPLACE INTO contractions(forme, developpe, traduction) VALUES (?, ?, ?)",
                         (norm(cols[0]), cols[1], cols[2]))
            n += 1
    return n


def charger_faux_amis(conn, path):
    """Table écrite à la main : mot anglais <TAB> piège <TAB> vrai sens. Renvoie le nombre de lignes."""
    n = 0
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            cols = [col.strip() for col in line.split("\t")]
            if len(cols) < 3 or not all(cols[:3]):
                raise ValueError("%s ligne %d : trois colonnes attendues" % (path, number))
            conn.execute("INSERT OR REPLACE INTO faux_amis(mot, piege, vrai) VALUES (?, ?, ?)",
                         (norm(cols[0]), cols[1], cols[2]))
            n += 1
    return n


# ---------------------------------------------------------------- expressions

TYPES_EXPRESSION = {"idiome", "courante", "utile", "proverbe", "particule"}
REGISTRES = ("vulgaire", "argot", "familier", "vieilli")  # du plus au moins « fort »
PARTICULES = {"up", "down", "out", "off", "on", "in", "over", "away", "back", "around", "about", "along",
              "through", "apart", "aside", "by", "forward", "ahead", "across", "after", "at", "into", "onto",
              "with", "for", "to", "from", "together", "behind", "under", "down", "round"}
MOTS_OUTILS = {"a", "an", "the", "to", "of", "in", "on", "at", "for", "with", "by", "and", "or", "but", "as",
               "is", "it", "its", "be", "are", "was", "were", "you", "your", "i", "my", "me", "he", "she",
               "we", "they", "one", "ones", "someone", "somebody", "something", "s", "t", "that", "this",
               "do", "does", "not", "no", "if", "so", "up", "out", "off"}
# Catégories du Wiktionnaire (categories_wiktionnaire.py) → niveau de langue.
CATEGORIES_REGISTRE = (
    ("vulgaire", ("english_vulgarities", "english_offensive_terms", "english_derogatory_terms",
                  "english_ethnic_slurs")),
    ("argot", ("english_slang",)),
    ("familier", ("english_informal_terms",)),
    ("vieilli", ("english_dated_terms", "english_obsolete_terms")),
)
# Balises de sens de l'édition anglaise (colonne sens.etiquettes) → niveau de langue.
BALISES_REGISTRE = (
    ("vulgaire", ("vulgar", "offensive", "derogatory", "slur", "ethnic")),
    ("argot", ("slang",)),
    ("familier", ("informal", "colloquial")),
    ("vieilli", ("dated", "archaic", "obsolete")),
)


def charger_categories(dossier):
    """Titres normalisés de chaque catégorie téléchargée : {nom_de_fichier_sans_extension: ensemble}."""
    cats = {}
    if not dossier or not os.path.isdir(dossier):
        return cats
    for nom in os.listdir(dossier):
        if nom.endswith(".txt"):
            with open(os.path.join(dossier, nom), encoding="utf-8") as f:
                cats[nom[:-4]] = {norm(ligne) for ligne in f.read().split("\n") if ligne.strip()}
    return cats


def _mots_de(texte):
    return [m for m in re.split(r"[^a-z0-9']+", fold(texte)) if m]


def type_expression(mot, nature, cats):
    """Type d'une entrée de plusieurs mots, ou None si ce n'est pas une expression (nom composé…)."""
    cle = norm(mot)
    mots = cle.split(" ")
    if len(mots) < 2 or len(mots) > 9 or len(cle) > 80 or nature in ("name", "prefix", "suffix", "?"):
        return None
    if nature == "proverb" or cle in cats.get("english_proverbs", ()):
        return "proverbe"
    if cle in cats.get("english_phrasal_verbs", ()) or (
            nature == "verb" and len(mots) == 2 and mots[1] in PARTICULES):
        return "particule"
    if cle in cats.get("english_idioms", ()):
        return "idiome"
    if nature in ("phrase", "prep_phrase", "intj", "adv", "prep", "conj"):
        return "courante"
    if nature == "verb":
        return "idiome"  # verbe de plusieurs mots qui n'est pas à particule : kick the bucket, spill the beans
    return None  # noms et adjectifs composés (ice cream, high school) : pas des expressions


def registre_expression(mot, balises, cats):
    cle = norm(mot)
    for registre, noms in CATEGORIES_REGISTRE:
        if any(cle in cats.get(n, ()) for n in noms):
            return registre
    texte = (balises or "").lower()
    for registre, mots in BALISES_REGISTRE:
        if any(m in texte for m in mots):
            return registre
    return ""


def classer_expressions(conn, cats):
    """Remplit `expressions` d'après la nature, les catégories du Wiktionnaire et les balises. Renvoie un compteur."""
    cur = conn.cursor()
    balises = {r[0]: r[1] for r in cur.execute(
        "SELECT s.mot_id, group_concat(s.etiquettes, ',') FROM sens s JOIN mots m ON m.id = s.mot_id "
        "WHERE m.mot LIKE '% %' GROUP BY s.mot_id")}
    compte = collections.Counter()
    lignes = cur.execute(
        "SELECT m.id, m.mot, m.nature FROM mots m WHERE m.mot LIKE '% %' "
        "AND EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = m.id)").fetchall()
    ajouts = []
    for mot_id, mot, nature in lignes:
        type_ = type_expression(mot, nature, cats)
        if type_ is None:
            continue
        reg = registre_expression(mot, balises.get(mot_id, ""), cats)
        ajouts.append((mot_id, type_, reg))
        compte[type_] += 1
        if reg:
            compte["registre_" + reg] += 1
    cur.executemany("INSERT OR IGNORE INTO expressions(mot_id, type, registre) VALUES (?, ?, ?)", ajouts)
    return compte


def charger_expressions_curees(conn, motif):
    """Expressions écrites à la main : expression <TAB> équivalent(s) <TAB> sens littéral <TAB> type <TAB>
    thème <TAB> registre <TAB> exemple. Une expression absente de la base est créée. Renvoie le nombre."""
    cur = conn.cursor()
    n = 0
    for chemin in sorted(glob.glob(motif)):
        with open(chemin, encoding="utf-8") as f:
            for numero, ligne in enumerate(f, 1):
                ligne = ligne.rstrip("\n")
                if not ligne.strip() or ligne.lstrip().startswith("#"):
                    continue
                cols = [c.strip() for c in ligne.split("\t")] + [""] * 7
                expression, fr, litteral, type_, theme, registre, exemple = cols[:7]
                if not expression or not fr or type_ not in TYPES_EXPRESSION or (
                        registre and registre not in REGISTRES):
                    raise ValueError("%s ligne %d : expression, équivalent et type valides attendus"
                                     % (chemin, numero))
                ligne_mot = cur.execute(
                    "SELECT m.id FROM mots m WHERE m.mot_recherche = ? ORDER BY "
                    "EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = m.id) DESC, m.id LIMIT 1",
                    (fold(expression),)).fetchone()
                mot_id = ligne_mot[0] if ligne_mot else trouver_ou_creer(cur, expression, "phrase", "en")
                principal = clip(fr.split(";")[0], 120)
                for variante in fr.split(";"):
                    ajouter_traduction(cur, mot_id, variante.strip(), "", "en+fr")
                cur.execute(
                    "INSERT OR REPLACE INTO expressions(mot_id, type, registre, litteral, fr, theme, exemple, curee)"
                    " VALUES (?, ?, ?, ?, ?, ?, ?, 1)",
                    (mot_id, type_, registre, clip(litteral, 160), principal, theme, clip(exemple, 200)))
                n += 1
    return n


def indexer_expressions(conn):
    """Index inversé : chaque mot (hors mots-outils) d'une expression renvoie à elle."""
    cur = conn.cursor()
    ajouts = set()
    for expr_id, recherche in cur.execute(
            "SELECT e.mot_id, m.mot_recherche FROM expressions e JOIN mots m ON m.id = e.mot_id").fetchall():
        for mot in _mots_de(recherche):
            mot = mot.strip("'")
            if len(mot) >= 2 and mot not in MOTS_OUTILS:
                ajouts.add((mot, expr_id))
    cur.executemany("INSERT OR IGNORE INTO expression_mots(mot, expr_id) VALUES (?, ?)", sorted(ajouts))
    return len(ajouts)


def deriver_renvois(conn):
    """Complète les renvois « forme -> mot de base » que l'import n'a pas vus.

    1. Les formes listées par le mot de base (turn -> turned, tooth -> teeth) deviennent des renvois
       inverses : on retrouve le mot de base en cherchant la forme.
    2. Un mot sans équivalent dont la définition (ou son contexte) dit « past tense of can »,
       « plural of X »… renvoie vers ce mot de base, s'il a des équivalents.
    Renvoie (renvois par formes, renvois par définitions).
    """
    cur = conn.cursor()
    avant = cur.execute("SELECT COUNT(*) FROM renvois").fetchone()[0]
    rows = cur.execute("SELECT f.forme, f.etiquettes, m.mot_norm, m.nature FROM formes f "
                       "JOIN mots m ON m.id = f.mot_id").fetchall()
    cur.executemany(
        "INSERT OR IGNORE INTO renvois(forme, forme_norm, nature, lemme_norm, etiquettes) "
        "VALUES (?, ?, ?, ?, ?)",
        [(form, norm(form), nature, lemme, etiq.replace(",", ", "))
         for form, etiq, lemme, nature in rows if " " not in form.strip() and norm(form) != lemme])
    apres_formes = cur.execute("SELECT COUNT(*) FROM renvois").fetchone()[0]

    avec_equivalent = {r[0] for r in cur.execute(
        "SELECT DISTINCT m.mot_norm FROM mots m JOIN traductions t ON t.mot_id = m.id")}
    candidats = cur.execute(
        "SELECT m.mot, m.mot_norm, m.nature, s.contexte, s.definition FROM mots m "
        "JOIN sens s ON s.mot_id = m.id "
        "WHERE NOT EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = m.id) "
        "ORDER BY s.ordre").fetchall()
    ajouts = []
    for mot, mot_norm, nature, contexte, definition in candidats:
        for texte in (contexte, definition):
            m = PATRON_RENVOI.match(texte or "")
            if not m or not any(g in m.group("et").casefold() for g in MOTS_GRAMMAIRE):
                continue
            lemme = norm(m.group("lemme"))
            if lemme != mot_norm and lemme in avec_equivalent:
                ajouts.append((mot, mot_norm, nature, lemme, clip(m.group("et"), 80)))
                break
    cur.executemany("INSERT OR IGNORE INTO renvois(forme, forme_norm, nature, lemme_norm, etiquettes) "
                    "VALUES (?, ?, ?, ?, ?)", ajouts)
    apres = cur.execute("SELECT COUNT(*) FROM renvois").fetchone()[0]
    return apres_formes - avant, apres - apres_formes


def finaliser(conn, frequence=None, contractions=CONTRACTIONS, seuil_rang=SEUIL_RANG_DEFAUT,
              faux_amis=FAUX_AMIS, categories=None, expressions=EXPRESSIONS):
    """Contractions, rangs, élagage, index. Renvoie un dictionnaire de chiffres."""
    res = {}
    cur = conn.cursor()
    res["contractions"] = charger_contractions(conn, contractions) if contractions else 0
    res["faux_amis"] = charger_faux_amis(conn, faux_amis) if faux_amis else 0

    if frequence:
        ranks = charger_frequence(frequence)
        cur.execute("CREATE TEMP TABLE freq(mot_norm TEXT PRIMARY KEY, rang INTEGER)")
        cur.executemany("INSERT INTO freq VALUES (?, ?)", ranks.items())
        cur.execute("UPDATE mots SET rang = (SELECT rang FROM freq WHERE freq.mot_norm = mots.mot_norm)")
        cur.execute("DROP TABLE freq")
        res["mots_classes"] = cur.execute("SELECT COUNT(*) FROM mots WHERE rang IS NOT NULL").fetchone()[0]

    res["renvois_par_formes"], res["renvois_par_definitions"] = deriver_renvois(conn)

    # Expressions : classées d'après la nature et les catégories du Wiktionnaire, puis celles écrites à la main.
    cats = charger_categories(categories)
    res["categories_wiktionnaire"] = {k: len(v) for k, v in sorted(cats.items())}
    res["expressions_classees"] = dict(classer_expressions(conn, cats))
    res["expressions_curees"] = charger_expressions_curees(conn, expressions) if expressions else 0

    # Élagage : un mot sans équivalent ni définition française n'est gardé que s'il est courant.
    avant = cur.execute("SELECT COUNT(*) FROM mots").fetchone()[0]
    cur.execute(
        "DELETE FROM mots WHERE id IN ("
        " SELECT m.id FROM mots m"
        " WHERE NOT EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = m.id)"
        "   AND NOT EXISTS (SELECT 1 FROM definitions_fr d WHERE d.mot_id = m.id)"
        "   AND (m.rang IS NULL OR m.rang > ?))", (seuil_rang,))
    for table in ("sens", "definitions_fr", "traductions", "formes", "audio", "prononciations", "relations",
                  "expressions"):
        cur.execute("DELETE FROM %s WHERE mot_id NOT IN (SELECT id FROM mots)" % table)
    cur.execute("DELETE FROM renvois WHERE NOT EXISTS "
                "(SELECT 1 FROM mots WHERE mots.mot_norm = renvois.lemme_norm)")
    res["mots_avant_elagage"] = avant
    res["mots_elagues"] = avant - cur.execute("SELECT COUNT(*) FROM mots").fetchone()[0]
    res["seuil_rang"] = seuil_rang

    cur.execute("CREATE INDEX IF NOT EXISTS ix_mots_recherche ON mots(mot_recherche)")
    cur.execute("CREATE INDEX IF NOT EXISTS ix_traductions_fr ON traductions(fr_norm)")
    cur.execute("CREATE INDEX IF NOT EXISTS ix_traductions_fr_recherche ON traductions(fr_recherche)")
    cur.execute("CREATE INDEX IF NOT EXISTS ix_renvois_lemme ON renvois(lemme_norm)")
    cur.execute("CREATE INDEX IF NOT EXISTS ix_mots_rang ON mots(rang)")
    cur.execute("CREATE INDEX IF NOT EXISTS ix_relations_mot ON relations(mot_id)")
    res["expression_mots"] = indexer_expressions(conn)

    meta = {
        "version_schema": VERSION_SCHEMA,
        "date_construction": datetime.date.today().isoformat(),
        "licence": "CC BY-SA 4.0 — données issues du Wiktionnaire (anglais et français) via kaikki.org",
        "seuil_rang": str(seuil_rang),
        "rang": "rang de fréquence d'après la liste wordfreq (CC BY-SA 4.0)" if frequence else "",
    }
    cur.executemany("INSERT OR REPLACE INTO meta(cle, valeur) VALUES (?, ?)", meta.items())
    conn.commit()
    cur.execute("ANALYZE")
    conn.commit()
    conn.execute("VACUUM")
    return res


# ---------------------------------------------------------------- rapport

def _un(cur, sql, *args):
    return cur.execute(sql, args).fetchone()[0]


def couverture(cur, words):
    """Pour les mots les plus courants : équivalent (direct, via renvoi, via contraction), définition seule, absent."""
    out = {}
    cats = []
    for w in words:
        if cur.execute("SELECT 1 FROM mots m JOIN traductions t ON t.mot_id = m.id "
                       "WHERE m.mot_norm = ? LIMIT 1", (w,)).fetchone():
            cats.append("equivalent")
        elif cur.execute("SELECT 1 FROM renvois r JOIN mots m ON m.mot_norm = r.lemme_norm "
                         "JOIN traductions t ON t.mot_id = m.id WHERE r.forme_norm = ? LIMIT 1",
                         (w,)).fetchone():
            cats.append("equivalent")
        elif cur.execute("SELECT 1 FROM contractions WHERE forme = ?", (w,)).fetchone():
            cats.append("equivalent")
        elif (cur.execute("SELECT 1 FROM mots WHERE mot_norm = ? LIMIT 1", (w,)).fetchone()
              or cur.execute("SELECT 1 FROM renvois WHERE forme_norm = ? LIMIT 1", (w,)).fetchone()):
            cats.append("definition_seule")
        else:
            cats.append("absent")
    # une liste plus courte que le premier seuil est évaluée en entier
    seuils = [k for k in SEUILS_COUVERTURE if k <= len(words)] or ([len(words)] if words else [])
    for k in seuils:
        chunk = cats[:k]
        n = len(chunk)
        counts = collections.Counter(chunk)
        out[str(k)] = {"mots_evalues": n}
        for cat in ("equivalent", "definition_seule", "absent"):
            out[str(k)][cat] = counts.get(cat, 0)
            out[str(k)][cat + "_pct"] = round(100.0 * counts.get(cat, 0) / n, 1)
    manques = [w for w, cat in zip(words[:5000], cats[:5000]) if cat != "equivalent"][:40]
    return out, manques


def rapport(conn, frequence=None):
    """Chiffres de qualité de la base finalisée, anomalies et anomalies bloquantes."""
    cur = conn.cursor()
    r = {}
    r["mots"] = _un(cur, "SELECT COUNT(*) FROM mots")
    r["natures"] = dict(cur.execute(
        "SELECT nature, COUNT(*) FROM mots GROUP BY nature ORDER BY 2 DESC LIMIT 12").fetchall())
    r["mots_avec_equivalent"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM traductions")
    r["mots_avec_definition_fr"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM definitions_fr")
    r["mots_avec_definition_en"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM sens")
    r["mots_edition_anglaise_seule"] = _un(cur, "SELECT COUNT(*) FROM mots WHERE src_en = 1 AND src_fr = 0")
    r["mots_edition_francaise_seule"] = _un(cur, "SELECT COUNT(*) FROM mots WHERE src_en = 0 AND src_fr = 1")
    r["mots_deux_editions"] = _un(cur, "SELECT COUNT(*) FROM mots WHERE src_en = 1 AND src_fr = 1")
    r["traductions"] = _un(cur, "SELECT COUNT(*) FROM traductions")
    r["traductions_par_source"] = dict(cur.execute(
        "SELECT source, COUNT(*) FROM traductions GROUP BY source").fetchall())
    r["mots_francais_distincts"] = _un(cur, "SELECT COUNT(DISTINCT fr_norm) FROM traductions")
    r["renvois"] = _un(cur, "SELECT COUNT(*) FROM renvois")
    r["formes"] = _un(cur, "SELECT COUNT(*) FROM formes")
    r["verbes"] = _un(cur, "SELECT COUNT(*) FROM mots WHERE nature = 'verb'")
    r["verbes_avec_formes"] = _un(cur, "SELECT COUNT(DISTINCT f.mot_id) FROM formes f "
                                       "JOIN mots m ON m.id = f.mot_id WHERE m.nature = 'verb'")
    r["audio_fichiers_distincts"] = _un(cur, "SELECT COUNT(DISTINCT fichier) FROM audio")
    r["mots_avec_audio"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM audio")
    r["audio_par_accent"] = dict(cur.execute(
        "SELECT accent, COUNT(DISTINCT fichier) FROM audio GROUP BY accent ORDER BY 2 DESC").fetchall())
    r["mots_avec_audio_us"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM audio WHERE accent = 'us'")
    r["mots_avec_audio_uk"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM audio WHERE accent = 'uk'")
    r["mots_avec_api"] = _un(cur, "SELECT COUNT(DISTINCT mot_id) FROM prononciations")
    r["contractions"] = _un(cur, "SELECT COUNT(*) FROM contractions")
    r["relations"] = _un(cur, "SELECT COUNT(*) FROM relations")
    r["faux_amis"] = _un(cur, "SELECT COUNT(*) FROM faux_amis")
    r["expressions"] = _un(cur, "SELECT COUNT(*) FROM expressions")
    r["expressions_curees"] = _un(cur, "SELECT COUNT(*) FROM expressions WHERE curee = 1")
    r["expressions_par_type"] = dict(cur.execute("SELECT type, COUNT(*) FROM expressions GROUP BY type").fetchall())

    anomalies = {
        "nature_inconnue": _un(cur, "SELECT COUNT(*) FROM mots WHERE nature = '?'"),
        "mots_sans_contenu": _un(
            cur, "SELECT COUNT(*) FROM mots m WHERE NOT EXISTS (SELECT 1 FROM sens s WHERE s.mot_id = m.id) "
                 "AND NOT EXISTS (SELECT 1 FROM traductions t WHERE t.mot_id = m.id) "
                 "AND NOT EXISTS (SELECT 1 FROM definitions_fr d WHERE d.mot_id = m.id)"),
        "renvois_orphelins": _un(
            cur, "SELECT COUNT(*) FROM renvois r WHERE NOT EXISTS "
                 "(SELECT 1 FROM mots m WHERE m.mot_norm = r.lemme_norm)"),
        "traductions_orphelines": _un(
            cur, "SELECT COUNT(*) FROM traductions WHERE mot_id NOT IN (SELECT id FROM mots)"),
        "audio_orphelin": _un(cur, "SELECT COUNT(*) FROM audio WHERE mot_id NOT IN (SELECT id FROM mots)"),
        "traductions_tres_longues": _un(cur, "SELECT COUNT(*) FROM traductions WHERE LENGTH(fr) > 60"),
    }
    r["anomalies"] = anomalies

    bloquantes = []
    if r["mots"] == 0:
        bloquantes.append("la base est vide")
    if r["traductions"] == 0:
        bloquantes.append("aucune traduction")
    for key in ("renvois_orphelins", "traductions_orphelines", "audio_orphelin", "mots_sans_contenu"):
        if anomalies[key]:
            bloquantes.append("%s : %d" % (key, anomalies[key]))

    if frequence:
        words = list(charger_frequence(frequence))
        r["couverture"], r["couverture_manques"] = couverture(cur, words)
        ref = max((e for k, e in r["couverture"].items() if int(k) <= 5000),
                  key=lambda e: e["mots_evalues"], default=None)
        if ref and ref["equivalent_pct"] < SEUIL_BLOQUANT:
            bloquantes.append("seulement %.1f %% des mots courants ont un équivalent (seuil %.0f %%)"
                              % (ref["equivalent_pct"], SEUIL_BLOQUANT))
    r["bloquantes"] = bloquantes
    return r


def rapport_markdown(r, taille=None):
    L = ["# Phase 1 — rapport de qualité de la base", ""]
    if taille is not None:
        L.append("Taille du fichier : %.1f Mo." % (taille / 1e6))
        L.append("")
    L += [
        "| Mesure | Valeur |", "| --- | --- |",
        "| Mots (graphie + nature) | %d |" % r["mots"],
        "| dont avec équivalent français | %d |" % r["mots_avec_equivalent"],
        "| dont avec définition française | %d |" % r["mots_avec_definition_fr"],
        "| dont avec définition anglaise | %d |" % r["mots_avec_definition_en"],
        "| édition anglaise seule / française seule / les deux | %d / %d / %d |" % (
            r["mots_edition_anglaise_seule"], r["mots_edition_francaise_seule"], r["mots_deux_editions"]),
        "| Traductions | %d (%s) |" % (
            r["traductions"], ", ".join("%s : %d" % kv for kv in sorted(r["traductions_par_source"].items()))),
        "| Mots français distincts | %d |" % r["mots_francais_distincts"],
        "| Renvois « forme de » | %d |" % r["renvois"],
        "| Verbes avec formes listées | %d sur %d |" % (r["verbes_avec_formes"], r["verbes"]),
        "| Fichiers audio distincts | %d (%s) |" % (
            r["audio_fichiers_distincts"], ", ".join("%s : %d" % kv for kv in r["audio_par_accent"].items())),
        "| Mots avec audio (US / UK) | %d (%d / %d) |" % (
            r["mots_avec_audio"], r["mots_avec_audio_us"], r["mots_avec_audio_uk"]),
        "| Mots avec transcription phonétique | %d |" % r["mots_avec_api"],
        "| Contractions écrites à la main | %d |" % r["contractions"],
        "| Mots liés (synonymes, contraires, famille) | %d |" % r["relations"],
        "| Faux amis écrits à la main | %d |" % r["faux_amis"],
        "| Expressions (dont %d écrites à la main) | %d (%s) |" % (
            r["expressions_curees"], r["expressions"],
            ", ".join("%s %d" % kv for kv in sorted(r["expressions_par_type"].items()))),
        "", "Natures : " + ", ".join("%s %d" % kv for kv in r["natures"].items()), "",
    ]
    if "couverture" in r:
        L += ["## Mots courants (liste wordfreq)", "",
              "| Mots les plus courants | Équivalent français | Définition seule | Absent |",
              "| --- | --- | --- | --- |"]
        for k, e in r["couverture"].items():
            L.append("| %s | %s %% | %s %% | %s %% |" % (
                k, e["equivalent_pct"], e["definition_seule_pct"], e["absent_pct"]))
        if r["couverture_manques"]:
            L += ["", "Sans équivalent parmi les 5000 premiers : " + ", ".join(r["couverture_manques"]), ""]
    L += ["## Anomalies", ""]
    L += ["- %s : %d" % kv for kv in r["anomalies"].items()]
    L += ["", "## Verdict", ""]
    L += (["- BLOQUANT : " + b for b in r["bloquantes"]] if r["bloquantes"]
          else ["Aucune anomalie bloquante."])
    return "\n".join(L) + "\n"


def gh_escape(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


# ---------------------------------------------------------------- ligne de commande

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("lire", help="lit une édition (JSONL sur l'entrée standard)")
    p.add_argument("--db", required=True)
    p.add_argument("--edition", required=True, choices=["en", "fr"])
    p.add_argument("--limit", type=int, default=None, help="s'arrêter après N lignes (essai rapide)")

    p = sub.add_parser("finaliser", help="contractions, rangs, élagage, index")
    p.add_argument("--db", required=True)
    p.add_argument("--frequence", help="liste de mots du plus au moins fréquent (liste_frequence.py)")
    p.add_argument("--contractions", default=CONTRACTIONS)
    p.add_argument("--seuil-rang", type=int, default=SEUIL_RANG_DEFAUT,
                   help="rang au-delà duquel un mot sans équivalent est supprimé")
    p.add_argument("--categories", help="dossier des catégories du Wiktionnaire (categories_wiktionnaire.py)")

    p = sub.add_parser("rapport", help="rapport de qualité")
    p.add_argument("--db", required=True)
    p.add_argument("--frequence")
    p.add_argument("--out", help="dossier où écrire rapport_base.md et rapport_base.json")
    p.add_argument("--strict", action="store_true", help="code de sortie 1 s'il y a une anomalie bloquante")

    args = ap.parse_args(argv)
    if args.cmd == "lire":
        conn = ouvrir(args.db)
        c = lire(conn, sys.stdin.buffer, args.edition, args.limit)
        conn.close()
        print("édition %s : %s" % (args.edition, dict(c)), file=sys.stderr)
        return 0
    if args.cmd == "finaliser":
        conn = ouvrir(args.db)
        res = finaliser(conn, args.frequence, args.contractions, args.seuil_rang, categories=args.categories)
        conn.close()
        print("finalisation : %s" % res, file=sys.stderr)
        return 0

    conn = sqlite3.connect(args.db)
    r = rapport(conn, args.frequence)
    conn.close()
    md = rapport_markdown(r, os.path.getsize(args.db))
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        with open(os.path.join(args.out, "rapport_base.md"), "w", encoding="utf-8") as f:
            f.write(md)
        with open(os.path.join(args.out, "rapport_base.json"), "w", encoding="utf-8") as f:
            json.dump(r, f, ensure_ascii=False, indent=2)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(md)
    if os.environ.get("GITHUB_ACTIONS"):
        print("::notice title=RAPPORT-BASE::" + gh_escape(md))
        for b in r["bloquantes"]:
            print("::error title=RAPPORT-BASE bloquant::" + gh_escape(b))
    else:
        sys.stdout.write(md)
    return 1 if (args.strict and r["bloquantes"]) else 0


if __name__ == "__main__":
    sys.exit(main())
