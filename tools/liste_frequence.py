#!/usr/bin/env python3
"""Phase 1 : écrit la liste des mots anglais les plus fréquents (un par ligne, du plus courant au moins courant).

Utilise le paquet `wordfreq` (données CC BY-SA 4.0) pour attribuer un rang de fréquence aux mots
de la base : rien d'autre n'est embarqué. Autonome (aucun import du dépôt).

Usage : python3 -I tools/liste_frequence.py --out frequence.txt [--count 100000]
"""
import argparse
import re
import sys
import unicodedata

WORD_RE = re.compile(r"^[a-z]+(?:'[a-z]+)?$")


def clean_words(raw_words):
    """Minuscules, apostrophe droite ; garde les mots faits de lettres (et d'une apostrophe interne)."""
    seen, out = set(), []
    for w in raw_words:
        w = unicodedata.normalize("NFC", str(w)).strip().casefold().replace("’", "'")
        if WORD_RE.match(w) and w not in seen:
            seen.add(w)
            out.append(w)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--count", type=int, default=100000)
    args = ap.parse_args(argv)
    from wordfreq import top_n_list  # import tardif : absent des tests
    words = clean_words(top_n_list("en", args.count))
    with open(args.out, "w", encoding="utf-8") as f:
        f.write("\n".join(words) + "\n")
    print("%d mots écrits dans %s" % (len(words), args.out), file=sys.stderr)


if __name__ == "__main__":
    main()
