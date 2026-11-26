-- Dictionnaire Anglais-Français : schéma de la base SQLite (version 1).
-- Appliqué par tools/construire_base.py. Les index de recherche (non uniques) sont
-- créés à la fin de la construction pour accélérer l'import ; la recherche plein texte
-- (FTS5) viendra en phase 2.

-- Une ligne par mot anglais et par nature grammaticale (« go » verbe, « go » nom…).
CREATE TABLE IF NOT EXISTS mots (
    id            INTEGER PRIMARY KEY,
    mot           TEXT NOT NULL,              -- graphie d'origine (NFC)
    mot_norm      TEXT NOT NULL,              -- NFC, minuscules
    mot_recherche TEXT NOT NULL,              -- sans accents ni majuscules
    nature        TEXT NOT NULL,              -- noun, verb, adj, adv, intj, name…
    rang          INTEGER,                    -- rang de fréquence (1 = le plus courant), ou NULL
    src_en        INTEGER NOT NULL DEFAULT 0, -- présent dans le Wiktionnaire anglais
    src_fr        INTEGER NOT NULL DEFAULT 0  -- présent dans le Wiktionnaire français
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_mots ON mots(mot, nature);
CREATE INDEX IF NOT EXISTS ix_mots_norm ON mots(mot_norm);

-- Définitions anglaises (édition anglaise), au plus 8 par mot.
CREATE TABLE IF NOT EXISTS sens (
    id         INTEGER PRIMARY KEY,
    mot_id     INTEGER NOT NULL,
    ordre      INTEGER NOT NULL,
    definition TEXT NOT NULL,
    contexte   TEXT NOT NULL DEFAULT '',      -- définition parente, s'il y en a une
    etiquettes TEXT NOT NULL DEFAULT '',      -- informal, archaic, UK…
    exemple    TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_sens_mot ON sens(mot_id);

-- Définitions françaises des mots anglais (édition française). Elles ne sont pas alignées
-- sur les sens anglais : on les garde séparées plutôt que de risquer un mauvais appariement.
CREATE TABLE IF NOT EXISTS definitions_fr (
    id     INTEGER PRIMARY KEY,
    mot_id INTEGER NOT NULL,
    ordre  INTEGER NOT NULL,
    texte  TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_definitions_fr ON definitions_fr(mot_id, texte);

-- Équivalents français. source : 'en' (édition anglaise), 'fr' (traduction inversée
-- de l'édition française) ou 'en+fr' (confirmé par les deux).
CREATE TABLE IF NOT EXISTS traductions (
    id           INTEGER PRIMARY KEY,
    mot_id       INTEGER NOT NULL,
    fr           TEXT NOT NULL,
    fr_norm      TEXT NOT NULL,
    fr_recherche TEXT NOT NULL,
    etiquette    TEXT NOT NULL DEFAULT '',    -- précision du Wiktionnaire (« to move »…)
    genre        TEXT NOT NULL DEFAULT '',    -- m, f, mf ou vide
    source       TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_traductions ON traductions(mot_id, fr_norm);

-- Formes fléchies listées dans l'entrée du mot de base (goes, went, gone…).
CREATE TABLE IF NOT EXISTS formes (
    id         INTEGER PRIMARY KEY,
    mot_id     INTEGER NOT NULL,
    forme      TEXT NOT NULL,
    etiquettes TEXT NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_formes ON formes(mot_id, forme, etiquettes);

-- Renvois « forme de » : went → go. Permettent de retrouver le mot de base depuis une forme.
CREATE TABLE IF NOT EXISTS renvois (
    forme      TEXT NOT NULL,
    forme_norm TEXT NOT NULL,
    nature     TEXT NOT NULL,
    lemme_norm TEXT NOT NULL,
    etiquettes TEXT NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_renvois ON renvois(forme_norm, nature, lemme_norm);

-- Enregistrements audio du Wiktionnaire (nom de fichier sur Wikimedia Commons).
-- accent : us, uk, au ou autre. Auteur et licence seront ajoutés par une étape distincte.
CREATE TABLE IF NOT EXISTS audio (
    id      INTEGER PRIMARY KEY,
    mot_id  INTEGER NOT NULL,
    fichier TEXT NOT NULL,
    accent  TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_audio ON audio(mot_id, fichier);

-- Transcriptions phonétiques (API).
CREATE TABLE IF NOT EXISTS prononciations (
    id     INTEGER PRIMARY KEY,
    mot_id INTEGER NOT NULL,
    accent TEXT NOT NULL,
    api    TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_prononciations ON prononciations(mot_id, accent, api);

-- Contractions écrites à la main (can't, I'm…) : tools/data/contractions.tsv.
CREATE TABLE IF NOT EXISTS contractions (
    forme      TEXT PRIMARY KEY,
    developpe  TEXT NOT NULL,
    traduction TEXT NOT NULL
);

-- Mots liés : synonymes (syn), contraires (ant), mots de la même famille (der).
CREATE TABLE IF NOT EXISTS relations (
    mot_id INTEGER NOT NULL,
    type   TEXT NOT NULL,
    mot    TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_relations ON relations(mot_id, type, mot);

-- Faux amis écrits à la main : tools/data/faux_amis.tsv.
CREATE TABLE IF NOT EXISTS faux_amis (
    mot   TEXT PRIMARY KEY,                   -- mot anglais, normalisé
    piege TEXT NOT NULL,                      -- ce qu'on croit à tort (« actuellement »)
    vrai  TEXT NOT NULL                       -- le vrai sens (« en fait, vraiment »)
);

-- Expressions anglaises de plusieurs mots (idiomes, phrases courantes ou utiles, proverbes, verbes
-- à particule). type : idiome, courante, utile, proverbe, particule. registre : vide, familier,
-- argot, vulgaire (vulgaire ou injurieux), vieilli. curee = 1 : écrite à la main (tools/data/expressions_*.tsv).
CREATE TABLE IF NOT EXISTS expressions (
    mot_id     INTEGER PRIMARY KEY,
    type       TEXT NOT NULL,
    registre   TEXT NOT NULL DEFAULT '',
    litteral   TEXT NOT NULL DEFAULT '',      -- sens mot à mot (expressions soignées)
    fr         TEXT NOT NULL DEFAULT '',      -- équivalent français recommandé (expressions soignées)
    theme      TEXT NOT NULL DEFAULT '',      -- voyage, restaurant… (phrases utiles)
    exemple    TEXT NOT NULL DEFAULT '',
    curee      INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_expressions_type ON expressions(type, curee);

-- Index inversé : mot (plié) → expressions qui le contiennent.
CREATE TABLE IF NOT EXISTS expression_mots (
    mot     TEXT NOT NULL,
    expr_id INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_expression_mots ON expression_mots(mot, expr_id);

CREATE TABLE IF NOT EXISTS meta (
    cle    TEXT PRIMARY KEY,
    valeur TEXT NOT NULL
);
