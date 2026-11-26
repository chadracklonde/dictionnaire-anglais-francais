#!/usr/bin/env python3
"""Télécharge, depuis le Wiktionnaire anglais, la liste des titres de catégories utiles pour classer
les expressions (idiomes, proverbes, verbes à particule) et leur niveau de langue (argot, vulgaire…).

  python3 tools/categories_wiktionnaire.py --sortie categories

Écrit un fichier texte par catégorie (un titre par ligne) : `english_idioms.txt`, etc.
`construire_base.py finaliser --categories categories` s'en sert. Une catégorie qui ne se télécharge pas
est signalée, mais n'arrête rien : la base se classe alors avec les seules balises de nature.
Les accès réseau sont injectés (`http`) pour tester sans réseau.
"""
import argparse
import os
import re
import sys
import urllib.parse

import audio_us

API = "https://en.wiktionary.org/w/api.php"
CATEGORIES = [
    "English idioms", "English proverbs", "English phrasal verbs",
    "English vulgarities", "English offensive terms", "English derogatory terms", "English ethnic slurs",
    "English slang", "English informal terms", "English dated terms", "English obsolete terms",
]
MAX_PAGES = 200  # garde-fou : 100 000 titres par catégorie au plus


def slug(categorie):
    return re.sub(r"[^a-z0-9]+", "_", categorie.lower()).strip("_")


def membres(categorie, http=audio_us.http_json):
    """Titres des pages (espace de noms principal) d'une catégorie, en suivant la pagination."""
    titres, suite = [], None
    for _ in range(MAX_PAGES):
        params = {"action": "query", "format": "json", "list": "categorymembers",
                  "cmtitle": "Category:" + categorie.replace(" ", "_"), "cmlimit": "500",
                  "cmnamespace": "0", "cmtype": "page"}
        if suite:
            params["cmcontinue"] = suite
        reponse = http(API + "?" + urllib.parse.urlencode(params))
        titres += [m["title"] for m in reponse.get("query", {}).get("categorymembers", []) if m.get("title")]
        suite = (reponse.get("continue") or {}).get("cmcontinue")
        if not suite:
            break
    return titres


def telecharger(sortie, categories=CATEGORIES, http=audio_us.http_json):
    os.makedirs(sortie, exist_ok=True)
    chiffres = {}
    for c in categories:
        try:
            titres = membres(c, http)
        except Exception as e:  # noqa: BLE001 - une catégorie manquante n'est pas fatale
            print("ECHEC %s : %s" % (c, str(e)[:100]), flush=True)
            continue
        with open(os.path.join(sortie, slug(c) + ".txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(titres) + "\n")
        chiffres[c] = len(titres)
        print("%-28s %6d titres" % (c, len(titres)), flush=True)
    return chiffres


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sortie", required=True)
    args = p.parse_args(argv)
    chiffres = telecharger(args.sortie)
    return 0 if chiffres else 1


if __name__ == "__main__":
    sys.exit(main())
