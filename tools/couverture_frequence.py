#!/usr/bin/env python3
"""Phase 0 : quelle part du vocabulaire anglais COURANT est couverte ?

Croise la liste des mots anglais les plus fréquents (paquet `wordfreq`, utilisé
seulement pour mesurer, rien n'est embarqué) avec les résultats de
analyse_wiktionnaire.py. Pour chaque mot, on suit les renvois « forme de »
(went → go) puis on le range dans l'une des quatre catégories :

  traduction     : au moins un équivalent français (deux éditions fusionnées)
  definition_fr  : pas d'équivalent, mais une définition française (édition française)
  entree_seule   : entrée existante sans équivalent ni définition française
  absent         : aucune entrée dans les deux éditions

Usage : python3 -I tools/couverture_frequence.py --dir resultats [--wordlist FICHIER]
Ce script est autonome : il n'importe aucun autre module du dépôt.
"""
import argparse
import collections
import gzip
import json
import os
import re
import sys
import unicodedata

THRESHOLDS = (1000, 5000, 10000, 20000, 50000)
CATEGORIES = ("traduction", "definition_fr", "entree_seule", "absent")
WORD_RE = re.compile(r"^[a-z]+(?:'[a-z]+)?$")


def norm(text):
    return unicodedata.normalize("NFC", str(text)).strip().casefold()


def load_entries(path):
    """Renvoie (mots existants, mots avec définition non-forme, dict mot -> mots de base)."""
    exists, defined, lemmas = set(), set(), collections.defaultdict(set)
    try:
        with gzip.open(path, "rt", encoding="utf-8") as f:
            for line in f:
                cols = line.rstrip("\n").split("\t")
                if len(cols) < 7:
                    continue
                word, _pos, is_form, lemma, _tr, has_def, _audio = cols[:7]
                exists.add(word)
                if is_form == "1" and lemma:
                    lemmas[word].add(lemma)
                if is_form == "0" and has_def == "1":
                    defined.add(word)
    except FileNotFoundError:
        pass
    return exists, defined, lemmas


def load_pair_words(path):
    words = set()
    try:
        with gzip.open(path, "rt", encoding="utf-8") as f:
            for line in f:
                en, _, fr = line.rstrip("\n").partition("\t")
                if en and fr:
                    words.add(en)
    except FileNotFoundError:
        pass
    return words


class Context:
    def __init__(self, d):
        self.en_exists, self.en_defined, en_lemmas = load_entries(
            os.path.join(d, "en_entries.tsv.gz"))
        self.fr_exists, self.fr_defined, fr_lemmas = load_entries(
            os.path.join(d, "fr_entries.tsv.gz"))
        self.lemmas = collections.defaultdict(set)
        for table in (en_lemmas, fr_lemmas):
            for word, targets in table.items():
                self.lemmas[word] |= targets
        self.pairs_en = load_pair_words(os.path.join(d, "en_pairs.tsv.gz"))
        self.pairs_all = self.pairs_en | load_pair_words(os.path.join(d, "fr_pairs.tsv.gz"))

    def candidates(self, word):
        """Le mot lui-même et, s'il est une forme, son ou ses mots de base."""
        return {word} | self.lemmas.get(word, set())

    def category(self, word):
        cands = self.candidates(word)
        if any(c in self.pairs_all for c in cands):
            return "traduction"
        if any(c in self.fr_defined for c in cands):
            return "definition_fr"
        if any(c in self.en_exists or c in self.fr_exists for c in cands):
            return "entree_seule"
        return "absent"

    def has_translation_en_only(self, word):
        return any(c in self.pairs_en for c in self.candidates(word))


def evaluate(ctx, words):
    """Calcule les répartitions par seuil et les exemples de mots sans équivalent."""
    result = {"seuils": {}, "exemples_sans_equivalent": []}
    cats = [(w, ctx.category(w)) for w in words]
    en_only = [ctx.has_translation_en_only(w) for w in words]
    # seuils atteignables ; une liste plus courte que le premier seuil est évaluée en entier
    seuils = [k for k in THRESHOLDS if k <= len(words)] or ([len(words)] if words else [])
    for k in seuils:
        chunk = cats[:k]
        counts = collections.Counter(c for _, c in chunk)
        n = len(chunk)
        entry = {"mots_evalues": n}
        for cat in CATEGORIES:
            entry[cat] = counts.get(cat, 0)
            entry[cat + "_pct"] = round(100.0 * counts.get(cat, 0) / n, 1)
        entry["traduction_edition_anglaise_seule"] = sum(en_only[:k])
        entry["traduction_edition_anglaise_seule_pct"] = round(100.0 * sum(en_only[:k]) / n, 1)
        entry["traduction_ou_definition_pct"] = round(
            100.0 * (counts.get("traduction", 0) + counts.get("definition_fr", 0)) / n, 1)
        result["seuils"][str(k)] = entry
    for w, cat in cats[:5000]:
        if cat in ("entree_seule", "absent"):
            result["exemples_sans_equivalent"].append("%s (%s)" % (w, cat))
            if len(result["exemples_sans_equivalent"]) >= 40:
                break
    return result


def build_markdown(res):
    lines = ["# Phase 0 — couverture du vocabulaire anglais courant", ""]
    seuils = res["seuils"]
    if not seuils:
        return "\n".join(lines + ["Aucun mot évalué."]) + "\n"
    lines += [
        "Mots les plus fréquents (liste `wordfreq`), formes ramenées à leur mot de base.", "",
        "| Mots les plus courants | Avec équivalent français | dont édition anglaise seule | "
        "Définition française seulement | Entrée sans équivalent | Absent | Équivalent ou définition |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for k, e in seuils.items():
        lines.append("| %s | %s %% | %s %% | %s %% | %s %% | %s %% | %s %% |" % (
            k, e["traduction_pct"], e["traduction_edition_anglaise_seule_pct"],
            e["definition_fr_pct"], e["entree_seule_pct"], e["absent_pct"],
            e["traduction_ou_definition_pct"]))
    if res["exemples_sans_equivalent"]:
        lines += ["", "## Mots très courants sans équivalent ni définition française", "",
                  ", ".join(res["exemples_sans_equivalent"])]
    return "\n".join(lines) + "\n"


def frequent_words(count=50000):
    """Mots anglais les plus fréquents, filtrés (lettres et apostrophe interne seulement)."""
    from wordfreq import top_n_list  # import tardif : absent des tests
    return clean_words(top_n_list("en", count))


def clean_words(raw_words):
    seen, out = set(), []
    for w in raw_words:
        w = norm(w).replace("’", "'")
        if WORD_RE.match(w) and w not in seen:
            seen.add(w)
            out.append(w)
    return out


def gh_escape(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dir", required=True)
    ap.add_argument("--wordlist", help="fichier de mots (un par ligne, du plus au moins fréquent)")
    args = ap.parse_args(argv)

    if args.wordlist:
        with open(args.wordlist, encoding="utf-8") as f:
            words = clean_words(f.read().split())
    else:
        words = frequent_words()
    ctx = Context(args.dir)
    res = evaluate(ctx, words)
    res["mots_dans_la_liste"] = len(words)

    md = build_markdown(res)
    with open(os.path.join(args.dir, "couverture_frequence.md"), "w", encoding="utf-8") as f:
        f.write(md)
    with open(os.path.join(args.dir, "couverture_frequence.json"), "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=2)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(md)
    if os.environ.get("GITHUB_ACTIONS"):
        print("::notice title=COUVERTURE-FREQUENCE::" + gh_escape(md))
    else:
        sys.stdout.write(md)


if __name__ == "__main__":
    main()
