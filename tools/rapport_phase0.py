#!/usr/bin/env python3
"""Phase 0 : rapport de synthèse à partir des résultats de analyse_wiktionnaire.py.

Lit <dir>/en_stats.json, <dir>/fr_stats.json et les deux fichiers de paires,
mesure la fusion (recouvrement des traductions) et, si demandé, le poids réel
d'un échantillon de fichiers audio. Écrit rapport_phase0.md et
rapport_phase0.json, ajoute le rapport au résumé du job et l'émet en annotation
GitHub (les journaux complets sont inaccessibles depuis une session Claude).

Usage : python3 -I tools/rapport_phase0.py --dir resultats [--probe-audio 80]
"""
import argparse
import gzip
import json
import os
import random
import statistics
import sys
import time
import urllib.error
import urllib.request

USER_AGENT = ("dictionnaire-anglais-francais/0.1 "
              "(https://github.com/chadracklonde/dictionnaire-anglais-francais)")


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def load_pairs(path):
    pairs = set()
    try:
        with gzip.open(path, "rt", encoding="utf-8") as f:
            for line in f:
                en, _, fr = line.rstrip("\n").partition("\t")
                if en and fr:
                    pairs.add((en, fr))
    except FileNotFoundError:
        pass
    return pairs


def pct(part, whole):
    return "%.1f %%" % (100.0 * part / whole) if whole else "n/a"


def n(value):
    return "{:,}".format(int(value or 0)).replace(",", " ")


def compare(pairs_en, pairs_fr):
    union = pairs_en | pairs_fr
    both = pairs_en & pairs_fr
    words_en = {p[0] for p in pairs_en}
    words_fr_side = {p[0] for p in pairs_fr}
    words_union = {p[0] for p in union}
    return {
        "paires_edition_en": len(pairs_en),
        "paires_edition_fr": len(pairs_fr),
        "paires_communes": len(both),
        "paires_union": len(union),
        "mots_anglais_edition_en": len(words_en),
        "mots_anglais_edition_fr": len(words_fr_side),
        "mots_anglais_union": len(words_union),
        "mots_anglais_gagnes_par_fusion": len(words_union - words_en),
        "mots_francais_union": len({p[1] for p in union}),
    }


def parse_total(headers):
    """Taille totale d'un fichier d'après Content-Range ("bytes 0-0/12345") ou Content-Length."""
    content_range = headers.get("Content-Range") or ""
    if "/" in content_range:
        total = content_range.rsplit("/", 1)[-1].strip()
        if total.isdigit():
            return int(total)
    length = headers.get("Content-Length")
    if length and length.isdigit():
        return int(length)
    return None


def _fetch_size(url):
    """Taille d'un fichier : HEAD, puis GET d'un seul octet si HEAD ne renseigne rien."""
    for method, extra in (("HEAD", {}), ("GET", {"Range": "bytes=0-0"})):
        req = urllib.request.Request(url, method=method,
                                     headers=dict({"User-Agent": USER_AGENT}, **extra))
        with urllib.request.urlopen(req, timeout=30) as r:
            size = parse_total(r.headers)
            if method == "GET":
                r.read(1)
        if size:
            return size
    return None


def probe_audio(urls, count, seed=1, pause=0.5):
    """Mesure le poids de `count` fichiers audio pris au hasard.

    Pause entre deux requêtes et une reprise après 429/503 : Wikimedia limite le débit.
    Renvoie (tailles, nombre d'échecs, causes d'échec).
    """
    urls = list(urls)
    random.Random(seed).shuffle(urls)
    sizes, failed, reasons = [], 0, {}
    for url in urls[:count]:
        size = None
        for attempt in (1, 2):
            try:
                size = _fetch_size(url)
                break
            except urllib.error.HTTPError as err:
                reason = "HTTP %d" % err.code
                if err.code in (429, 503) and attempt == 1:
                    time.sleep(5)
                    continue
                reasons[reason] = reasons.get(reason, 0) + 1
                break
            except Exception as err:  # réseau, délai dépassé, URL invalide
                reason = type(err).__name__
                reasons[reason] = reasons.get(reason, 0) + 1
                break
        if size:
            sizes.append(size)
        else:
            failed += 1
        time.sleep(pause)
    return sizes, failed, reasons


def build_report(en, fr, cmp_, audio, samples_en, samples_fr):
    lines = ["# Phase 0 — analyse des sources du Wiktionnaire", ""]

    lines += ["## Wiktionnaire anglais", ""]
    if en:
        e = en.get("entrees_anglaises", 0)
        lines += [
            "- Lignes lues : %s ; entrées anglaises : %s" % (n(en.get("lignes")), n(e)),
            "- Avec définition : %s (%s)" % (n(en.get("anglais_avec_definition")),
                                           pct(en.get("anglais_avec_definition", 0), e)),
            "- Formes fléchies renvoyant à un mot de base : %s" % n(en.get("anglais_formes_renvoi")),
            "- Avec traduction française : %s (%s) ; traductions : %s, dont rattachées à un sens : %s"
            % (n(en.get("anglais_avec_traduction_fr")),
               pct(en.get("anglais_avec_traduction_fr", 0), e),
               n(en.get("traductions_fr")),
               pct(en.get("traductions_fr_avec_sens", 0), en.get("traductions_fr", 0))),
            "- Avec API : %s ; avec audio : %s (%s) ; audio US : %s ; audio UK : %s ; fichiers audio distincts : %s"
            % (n(en.get("anglais_avec_api")), n(en.get("anglais_avec_audio")),
               pct(en.get("anglais_avec_audio", 0), e), n(en.get("anglais_audio_us")),
               n(en.get("anglais_audio_uk")), n(en.get("fichiers_audio_distincts"))),
            "- Verbes : %s ; avec formes : %s ; avec passé et participe : %s"
            % (n(en.get("verbes")), n(en.get("verbes_avec_formes")),
               n(en.get("verbes_passe_et_participe"))),
            "- Balises audio les plus fréquentes : %s" % ", ".join(
                "%s (%s)" % (k, n(v)) for k, v in list(en.get("balises_audio", {}).items())[:8]),
        ]
    else:
        lines.append("- Aucun résultat : l'analyse de l'édition anglaise n'a pas abouti.")

    lines += ["", "## Wiktionnaire français", ""]
    if fr:
        lines += [
            "- Lignes lues : %s ; entrées françaises : %s ; entrées anglaises : %s"
            % (n(fr.get("lignes")), n(fr.get("entrees_francaises")), n(fr.get("entrees_anglaises"))),
            "- Entrées françaises avec traduction anglaise : %s (%s) ; traductions : %s, dont rattachées à un sens : %s"
            % (n(fr.get("francais_avec_traduction_en")),
               pct(fr.get("francais_avec_traduction_en", 0), fr.get("entrees_francaises", 0)),
               n(fr.get("traductions_en")),
               pct(fr.get("traductions_en_avec_sens", 0), fr.get("traductions_en", 0))),
            "- Entrées anglaises définies en français : %s ; avec audio : %s"
            % (n(fr.get("anglais_defini_en_francais")), n(fr.get("anglais_avec_audio"))),
        ]
    else:
        lines.append("- Aucun résultat : l'analyse de l'édition française n'a pas abouti.")

    lines += ["", "## Fusion des traductions (couples mot anglais — mot français)", ""]
    lines += [
        "| Mesure | Valeur |", "| --- | --- |",
        "| Couples, édition anglaise | %s |" % n(cmp_["paires_edition_en"]),
        "| Couples, édition française (inversés) | %s |" % n(cmp_["paires_edition_fr"]),
        "| Couples communs aux deux | %s |" % n(cmp_["paires_communes"]),
        "| Couples après fusion | %s |" % n(cmp_["paires_union"]),
        "| Mots anglais couverts, édition anglaise seule | %s |" % n(cmp_["mots_anglais_edition_en"]),
        "| Mots anglais couverts après fusion | %s |" % n(cmp_["mots_anglais_union"]),
        "| Mots anglais gagnés grâce à l'édition française | %s |" % n(cmp_["mots_anglais_gagnes_par_fusion"]),
        "| Mots français couverts après fusion | %s |" % n(cmp_["mots_francais_union"]),
    ]

    lines += ["", "## Poids de l'audio", ""]
    if audio.get("mesures"):
        lines += [
            "- Fichiers mesurés : %d (échecs : %d%s)" % (
                audio["mesures"], audio["echecs"],
                " — " + ", ".join("%s × %d" % kv for kv in audio.get("causes_echecs", {}).items())
                if audio.get("causes_echecs") else ""),
            "- Taille moyenne : %.1f Ko ; médiane : %.1f Ko ; maximum : %.1f Ko"
            % (audio["moyenne_ko"], audio["mediane_ko"], audio["max_ko"]),
            "- Estimation pour %s fichiers distincts : environ %.0f Mo (extrapolation d'un échantillon)"
            % (n(audio["fichiers_distincts"]), audio["estimation_totale_mo"]),
        ]
    else:
        lines.append("- Poids non mesuré (aucun échantillon ou réseau indisponible)%s." % (
            " ; causes : " + ", ".join("%s × %d" % kv for kv in audio.get("causes_echecs", {}).items())
            if audio.get("causes_echecs") else ""))

    for title, sample in (("Échantillon, édition anglaise", samples_en),
                          ("Échantillon, édition française", samples_fr)):
        if sample:
            lines += ["", "## " + title, ""]
            for s in sample[:8]:
                trs = ", ".join(
                    t["mot"] + (" (%s)" % t["sens"] if t.get("sens") else "")
                    for t in s.get("traductions", [])[:4])
                lines.append("- **%s** (%s) : %s" % (s.get("mot"), s.get("nature"), trs))
    return "\n".join(lines) + "\n"


def gh_escape(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dir", required=True)
    ap.add_argument("--probe-audio", type=int, default=0,
                    help="nombre de fichiers audio dont mesurer le poids")
    args = ap.parse_args(argv)

    d = args.dir
    en = load_json(os.path.join(d, "en_stats.json"))
    fr = load_json(os.path.join(d, "fr_stats.json"))
    pairs_en = load_pairs(os.path.join(d, "en_pairs.tsv.gz"))
    pairs_fr = load_pairs(os.path.join(d, "fr_pairs.tsv.gz"))
    samples_en = load_json(os.path.join(d, "en_samples.json")) or []
    samples_fr = load_json(os.path.join(d, "fr_samples.json")) or []

    cmp_ = compare(pairs_en, pairs_fr)

    audio = {}
    urls = en.get("urls_audio_echantillon") or []
    if args.probe_audio and urls:
        sizes, failed, reasons = probe_audio(urls, args.probe_audio)
        if sizes:
            mean = statistics.mean(sizes)
            audio = {
                "mesures": len(sizes), "echecs": failed, "causes_echecs": reasons,
                "moyenne_ko": mean / 1024, "mediane_ko": statistics.median(sizes) / 1024,
                "max_ko": max(sizes) / 1024,
                "fichiers_distincts": en.get("fichiers_audio_distincts", 0),
                "estimation_totale_mo": mean * en.get("fichiers_audio_distincts", 0) / 1048576,
            }
        else:
            audio = {"mesures": 0, "echecs": failed, "causes_echecs": reasons}

    md = build_report(en, fr, cmp_, audio, samples_en, samples_fr)
    with open(os.path.join(d, "rapport_phase0.md"), "w", encoding="utf-8") as f:
        f.write(md)
    with open(os.path.join(d, "rapport_phase0.json"), "w", encoding="utf-8") as f:
        json.dump({"en": {k: v for k, v in en.items() if k != "urls_audio_echantillon"},
                   "fr": fr, "fusion": cmp_, "audio": audio},
                  f, ensure_ascii=False, indent=2, sort_keys=True)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(md)
    if os.environ.get("GITHUB_ACTIONS"):
        print("::notice title=RAPPORT-PHASE0::" + gh_escape(md))
    else:
        sys.stdout.write(md)


if __name__ == "__main__":
    main()
