#!/usr/bin/env python3
"""Audio américain : choisit un enregistrement par mot, relève auteur et licence sur Wikimedia
Commons, télécharge les fichiers et les découpe en packs.

  python3 tools/audio_us.py --db dictionnaire-en-fr.db --sortie audio [--limite 200]

- `us_core` : les mots dont le rang de fréquence est inférieur à `--rang-coeur` (5000 par défaut),
  livrés avec l'application ;
- `us_1`, `us_2`… : le reste, par rang décroissant de fréquence, en packs facultatifs de
  `--taille-pack-mo` Mo au plus.

Seuls les fichiers sous licence libre qui impose au plus l'attribution et le partage dans les
mêmes conditions (CC BY, CC BY-SA, CC0, domaine public) sont gardés ; l'auteur et la licence de
chaque fichier sont écrits dans `audio_index.json`, pour être affichés dans l'application.
Les accès réseau sont injectés (`http_json`, `http_octets`) pour pouvoir tester sans réseau.
"""
import argparse
import collections
import concurrent.futures
import html
import json
import os
import re
import sqlite3
import sys
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = ("dicoenfr-audio/1.0 (https://github.com/chadracklonde/dictionnaire-anglais-francais; "
              "dictionnaire libre hors ligne)")
RANG_COEUR = 5000
TAILLE_PACK_MO = 350
TAILLE_MAX_FICHIER = 400 * 1024  # un enregistrement plus lourd est écarté
LOT_API = 50


# ---------------------------------------------------------------- réseau

def http_json(url, tentatives=4, pause=2.0):
    """GET d'une réponse JSON, avec nouvelles tentatives."""
    derniere = None
    for n in range(tentatives):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # réseau, 429, 5xx
            derniere = e
            time.sleep(pause * (n + 1))
    raise RuntimeError("échec de %s : %s" % (url[:120], derniere))


def http_octets(url, tentatives=4, pause=2.0):
    derniere = None
    for n in range(tentatives):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except Exception as e:
            derniere = e
            time.sleep(pause * (n + 1))
    raise RuntimeError("échec de %s : %s" % (url[:120], derniere))


# ---------------------------------------------------------------- sélection

def selectionner(conn):
    """Un enregistrement américain par mot (le premier), sans doublon de fichier, par rang."""
    lignes = conn.execute(
        "SELECT a.fichier, m.mot, m.rang FROM audio a JOIN mots m ON m.id = a.mot_id "
        "WHERE a.accent = 'us' AND a.id = (SELECT MIN(a2.id) FROM audio a2 "
        "                                   WHERE a2.mot_id = a.mot_id AND a2.accent = 'us') "
        "ORDER BY m.rang IS NULL, m.rang, m.mot, a.id").fetchall()
    vus, sortie = set(), []
    for fichier, mot, rang in lignes:
        if fichier in vus:
            continue
        vus.add(fichier)
        sortie.append({"fichier": fichier, "mot": mot, "rang": rang})
    return sortie


def licence_acceptable(nom):
    """Vrai pour CC BY, CC BY-SA, CC0 et le domaine public ; faux pour NC, ND, GFDL, etc."""
    bas = (nom or "").strip().lower()
    if not bas or re.search(r"(^|[ -])n[cd]($|[ -])", bas):
        return False
    return bool(re.match(r"(cc[ -]by|cc[ -]?0|cc[ -]zero|public domain|pd($|[ -])|attribution)", bas))


def _texte(valeur, limite=140):
    """Texte brut d'un champ HTML de Commons."""
    brut = re.sub(r"<[^>]+>", " ", str(valeur or ""))
    return " ".join(html.unescape(brut).split())[:limite]


def _majuscule(titre):
    return titre[:1].upper() + titre[1:] if titre else titre


def recuperer_metadonnees(fichiers, http=http_json, lot=LOT_API):
    """Pour chaque nom de fichier Commons : url, taille, type, auteur, licence. Renvoie un dict."""
    infos = {}
    for debut in range(0, len(fichiers), lot):
        groupe = fichiers[debut:debut + lot]
        titres = ["File:" + f.replace("_", " ") for f in groupe]
        requete = urllib.parse.urlencode({
            "action": "query", "format": "json", "formatversion": "2", "prop": "imageinfo",
            "iiprop": "url|size|mime|extmetadata",
            "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl",
            "titles": "|".join(titres),
        })
        reponse = http(API + "?" + requete)
        requete_data = reponse.get("query", {})
        # Commons peut normaliser le titre (majuscule initiale, espaces) : on retrouve l'original.
        original = {_majuscule(t): f for t, f in zip(titres, groupe)}
        for n in requete_data.get("normalized", []) or []:
            if n.get("from") in dict(zip(titres, groupe)):
                original[n["to"]] = dict(zip(titres, groupe))[n["from"]]
        for page in requete_data.get("pages", []) or []:
            fichier = original.get(page.get("title"))
            info = (page.get("imageinfo") or [None])[0]
            if fichier is None or info is None or page.get("missing"):
                continue
            meta = info.get("extmetadata") or {}
            infos[fichier] = {
                "url": info.get("url", ""),
                "taille": int(info.get("size") or 0),
                "mime": info.get("mime", ""),
                "auteur": _texte((meta.get("Artist") or {}).get("value")),
                "licence": _texte((meta.get("LicenseShortName") or {}).get("value"), 40),
                "licence_url": _texte((meta.get("LicenseUrl") or {}).get("value"), 200),
                "page": info.get("descriptionurl", ""),
            }
    return infos


def filtrer(candidats, infos):
    """Garde les fichiers connus de Commons, audio, légers et sous licence acceptable."""
    gardes, refus = [], collections.Counter()
    for c in candidats:
        info = infos.get(c["fichier"])
        if info is None:
            refus["introuvable"] += 1
        elif not (info["mime"].startswith("audio") or info["mime"] == "application/ogg"):
            refus["pas_audio"] += 1
        elif not info["url"] or info["taille"] <= 0 or info["taille"] > TAILLE_MAX_FICHIER:
            refus["taille"] += 1
        elif not licence_acceptable(info["licence"]):
            refus["licence"] += 1
        else:
            gardes.append({**c, **info})
    return gardes, refus


# ---------------------------------------------------------------- packs

def nom_local(fichier):
    """Nom de fichier sûr pour Android (lettres, chiffres, point, tiret, souligné)."""
    nom = re.sub(r"[^A-Za-z0-9._-]+", "_", fichier.replace(" ", "_")).strip("._") or "audio"
    return nom[:120]


def planifier(gardes, rang_coeur=RANG_COEUR, taille_pack_mo=TAILLE_PACK_MO):
    """Répartit les fichiers (déjà triés par rang) : `us_core`, puis `us_1`, `us_2`…"""
    limite = taille_pack_mo * 1024 * 1024
    packs = collections.OrderedDict()
    noms_pris = set()
    courant, taille_courante = None, 0
    for g in gardes:
        if g["rang"] is not None and g["rang"] <= rang_coeur:
            pack = "us_core"
        else:
            if courant is None or taille_courante + g["taille"] > limite:
                courant = "us_%d" % (sum(1 for p in packs if p != "us_core") + 1)
                taille_courante = 0
            pack = courant
            taille_courante += g["taille"]
        nom = nom_local(g["fichier"])
        while (pack, nom) in noms_pris:  # deux noms qui se réduisent au même texte
            nom = "x" + nom
        noms_pris.add((pack, nom))
        g["pack"], g["nom"] = pack, nom
        packs.setdefault(pack, []).append(g)
    return packs


def telecharger(packs, sortie, http=http_octets, workers=4, pause=0.05):
    """Écrit chaque fichier dans sortie/<pack>/<nom>. Renvoie les fichiers non téléchargés."""
    taches = [(g, os.path.join(sortie, "audio_" + p)) for p, liste in packs.items() for g in liste]
    for _, dossier in taches:
        os.makedirs(dossier, exist_ok=True)
    echecs = []

    def une(tache):
        g, dossier = tache
        try:
            donnees = http(g["url"])
            if not donnees or abs(len(donnees) - g["taille"]) > 64:
                raise RuntimeError("taille inattendue (%d au lieu de %d)" % (len(donnees), g["taille"]))
            with open(os.path.join(dossier, g["nom"]), "wb") as f:
                f.write(donnees)
            time.sleep(pause)
            return None
        except Exception as e:
            return (g["fichier"], str(e)[:120])

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
        for resultat in ex.map(une, taches):
            if resultat:
                echecs.append(resultat)
    return echecs


def construire_index(packs, echecs):
    perdus = {f for f, _ in echecs}
    index = {"version": 1, "accent": "us", "packs": {}, "fichiers": {}}
    for pack, liste in packs.items():
        bons = [g for g in liste if g["fichier"] not in perdus]
        index["packs"]["audio_" + pack] = {
            "fichiers": len(bons),
            "octets": sum(g["taille"] for g in bons),
            "coeur": pack == "us_core",
        }
        for g in bons:
            index["fichiers"][g["fichier"]] = {
                "p": "audio_" + pack, "f": g["nom"], "a": g["auteur"], "l": g["licence"],
                "u": g["licence_url"], "d": g["page"],
            }
    return index


def rapport(candidats, refus, packs, echecs, index):
    mo = lambda o: "%.1f Mo" % (o / 1048576)
    lignes = ["# Audio américain — rapport", "",
              "Mots candidats (un enregistrement américain par mot) : %d" % len(candidats),
              "Écartés : " + (", ".join("%s %d" % kv for kv in sorted(refus.items())) or "aucun"),
              "Téléchargements échoués : %d" % len(echecs), "",
              "| Pack | Fichiers | Poids |", "| --- | --- | --- |"]
    for nom, p in index["packs"].items():
        lignes.append("| %s%s | %d | %s |" % (nom, " (livré avec l'application)" if p["coeur"] else "",
                                              p["fichiers"], mo(p["octets"])))
    licences = collections.Counter(f["l"] for f in index["fichiers"].values())
    lignes += ["", "Licences : " + ", ".join("%s %d" % kv for kv in licences.most_common()), ""]
    if echecs:
        lignes += ["Exemples d'échecs : " + "; ".join("%s (%s)" % e for e in echecs[:5]), ""]
    return "\n".join(lignes)


# ---------------------------------------------------------------- programme

def executer(db, sortie, rang_coeur=RANG_COEUR, taille_pack_mo=TAILLE_PACK_MO, limite=None,
             workers=4, http_meta=http_json, http_fichier=http_octets, pause=0.05):
    conn = sqlite3.connect(db)
    candidats = selectionner(conn)
    conn.close()
    if limite:
        candidats = candidats[:limite]
    infos = recuperer_metadonnees([c["fichier"] for c in candidats], http=http_meta)
    gardes, refus = filtrer(candidats, infos)
    packs = planifier(gardes, rang_coeur, taille_pack_mo)
    os.makedirs(sortie, exist_ok=True)
    echecs = telecharger(packs, sortie, http=http_fichier, workers=workers, pause=pause)
    index = construire_index(packs, echecs)
    with open(os.path.join(sortie, "audio_index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, separators=(",", ":"))
    texte = rapport(candidats, refus, packs, echecs, index)
    with open(os.path.join(sortie, "rapport_audio.md"), "w", encoding="utf-8") as f:
        f.write(texte + "\n")
    return index, texte


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--db", required=True)
    p.add_argument("--sortie", required=True)
    p.add_argument("--rang-coeur", type=int, default=RANG_COEUR)
    p.add_argument("--taille-pack-mo", type=int, default=TAILLE_PACK_MO)
    p.add_argument("--limite", type=int, default=None, help="essai : seulement les N mots les plus courants")
    p.add_argument("--workers", type=int, default=4)
    args = p.parse_args(argv)
    index, texte = executer(args.db, args.sortie, args.rang_coeur, args.taille_pack_mo, args.limite,
                            args.workers)
    print(texte)
    return 0 if index["fichiers"] else 1


if __name__ == "__main__":
    sys.exit(main())
