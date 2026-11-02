#!/usr/bin/env python3
"""Phase 0 : analyse d'une extraction JSONL du Wiktionnaire (kaikki.org).

Lit le JSONL sur l'entrée standard (déjà décompressé), sans rien stocker en
mémoire sauf des compteurs, l'ensemble des paires (anglais, français) et
quelques échantillons. Écrit dans --out :

  <edition>_stats.json     chiffres de couverture
  <edition>_pairs.tsv.gz   paires "mot anglais <TAB> mot français"
  <edition>_samples.json   échantillons lisibles pour relecture

Usage :
  curl -sSL URL | gunzip -c | python3 -I tools/analyse_wiktionnaire.py \
      --edition en --out resultats [--limit 100000]

--edition en : Wiktionnaire anglais (entrées anglaises, traductions vers le français)
--edition fr : Wiktionnaire français (entrées françaises -> traductions anglaises,
               et entrées anglaises définies en français)
"""
import argparse
import collections
import gzip
import json
import os
import random
import sys
import unicodedata

try:  # orjson est bien plus rapide ; le module standard suffit pour les tests
    import orjson

    loads = orjson.loads
except ImportError:  # pragma: no cover
    loads = json.loads

US_TAGS = {"us", "general-american", "american", "general american"}
UK_TAGS = {"uk", "received-pronunciation", "british", "rp"}
AUDIO_URL_SAMPLE = 300  # URL d'audio gardées pour mesurer le poids réel
SAMPLE_SIZE = 25


def norm(text):
    """Forme de comparaison : NFC, sans espaces autour, sans casse."""
    return unicodedata.normalize("NFC", str(text)).strip().casefold()


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


def audio_url_of(sound):
    """URL utilisable pour mesurer le fichier, ou None."""
    for key in ("ogg_url", "mp3_url", "opus_url", "flac_url", "wav_url"):
        url = sound.get(key)
        if url:
            return str(url)
    name = sound.get("audio")
    if name:
        return "https://commons.wikimedia.org/wiki/Special:FilePath/" + str(name).replace(" ", "_")
    return None


class Reservoir:
    """Échantillon uniforme de taille fixe sur un flux (graine fixe)."""

    def __init__(self, size, seed=42):
        self.size = size
        self.items = []
        self.seen = 0
        self.rng = random.Random(seed)

    def add(self, item):
        self.seen += 1
        if len(self.items) < self.size:
            self.items.append(item)
        else:
            j = self.rng.randrange(self.seen)
            if j < self.size:
                self.items[j] = item


def first_gloss(entry):
    for sense in entry.get("senses") or []:
        glosses = sense.get("glosses")
        if glosses:
            return str(glosses[0])
    return None


def has_sense_label(tr):
    return bool(tr.get("sense") or tr.get("sense_index"))


def analyse(lines, edition, limit=None):
    """Parcourt un itérable de lignes JSON. Renvoie (stats, paires, échantillons)."""
    c = collections.Counter()
    pos_counter = collections.Counter()
    audio_tags = collections.Counter()
    audio_files = set()
    audio_urls = Reservoir(AUDIO_URL_SAMPLE, seed=7)
    pairs = set()
    samples = Reservoir(SAMPLE_SIZE)

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
            c["lignes_illisibles"] += 1
            continue
        lang = e.get("lang_code")
        word = e.get("word")
        if not word:
            c["sans_mot"] += 1
            continue

        if edition == "en":
            if lang != "en":
                continue
            c["entrees_anglaises"] += 1
            pos = e.get("pos") or "?"
            pos_counter[pos] += 1
            senses = e.get("senses") or []
            n_def = sum(1 for s in senses if s.get("glosses"))
            if n_def:
                c["anglais_avec_definition"] += 1
            if any(s.get("form_of") or s.get("alt_of") for s in senses):
                c["anglais_formes_renvoi"] += 1
            if any(s.get("examples") for s in senses):
                c["anglais_avec_exemple"] += 1

            trs = [t for t in (e.get("translations") or [])
                   if t.get("lang_code") == "fr" and t.get("word")]
            if trs:
                c["anglais_avec_traduction_fr"] += 1
                c["traductions_fr"] += len(trs)
                c["traductions_fr_avec_sens"] += sum(1 for t in trs if has_sense_label(t))
                for t in trs:
                    pairs.add((norm(word), norm(t["word"])))
            _count_sounds(e, c, audio_tags, audio_files, audio_urls)
            _count_verb(e, pos, c)
            if trs and (e.get("sounds") or []) and n_def:
                samples.add({
                    "mot": word, "nature": pos, "definition": first_gloss(e),
                    "traductions": [
                        {"mot": t["word"], "sens": t.get("sense")} for t in trs[:6]],
                    "audio": [a for a in (audio_of(s) for s in e.get("sounds") or []) if a][:2],
                })

        elif edition == "fr":
            if lang == "fr":
                c["entrees_francaises"] += 1
                trs = [t for t in (e.get("translations") or [])
                       if t.get("lang_code") == "en" and t.get("word")]
                if trs:
                    c["francais_avec_traduction_en"] += 1
                    c["traductions_en"] += len(trs)
                    c["traductions_en_avec_sens"] += sum(1 for t in trs if has_sense_label(t))
                    for t in trs:
                        pairs.add((norm(t["word"]), norm(word)))
                    samples.add({
                        "mot": word, "nature": e.get("pos"), "definition": first_gloss(e),
                        "traductions": [
                            {"mot": t["word"], "sens": t.get("sense")} for t in trs[:6]],
                    })
            elif lang == "en":
                c["entrees_anglaises"] += 1
                if any(s.get("glosses") for s in e.get("senses") or []):
                    c["anglais_defini_en_francais"] += 1
                pos_counter[e.get("pos") or "?"] += 1
                _count_sounds(e, c, audio_tags, audio_files, audio_urls)
                _count_verb(e, e.get("pos"), c)
        else:
            raise ValueError("édition inconnue : %r" % edition)

    stats = dict(c)
    stats["edition"] = edition
    stats["paires_distinctes"] = len(pairs)
    stats["mots_anglais_distincts_dans_paires"] = len({p[0] for p in pairs})
    stats["mots_francais_distincts_dans_paires"] = len({p[1] for p in pairs})
    stats["fichiers_audio_distincts"] = len(audio_files)
    stats["natures"] = dict(pos_counter.most_common(25))
    stats["balises_audio"] = dict(audio_tags.most_common(30))
    stats["urls_audio_echantillon"] = audio_urls.items
    return stats, pairs, samples.items


def _count_sounds(e, c, audio_tags, audio_files, audio_urls):
    sounds = e.get("sounds") or []
    if any(s.get("ipa") for s in sounds):
        c["anglais_avec_api"] += 1
    with_audio = [s for s in sounds if audio_of(s)]
    if not with_audio:
        return
    c["anglais_avec_audio"] += 1
    tags_seen = set()
    for s in with_audio:
        name = audio_of(s)
        if name not in audio_files:
            audio_files.add(name)
            url = audio_url_of(s)
            if url:
                audio_urls.add(url)
        for t in s.get("tags") or []:
            audio_tags[str(t)] += 1
            tags_seen.add(str(t).casefold())
    if tags_seen & US_TAGS:
        c["anglais_audio_us"] += 1
    if tags_seen & UK_TAGS:
        c["anglais_audio_uk"] += 1


def _count_verb(e, pos, c):
    if pos != "verb":
        return
    c["verbes"] += 1
    forms = e.get("forms") or []
    if forms:
        c["verbes_avec_formes"] += 1
    tags = set()
    for f in forms:
        tags.update(str(t).casefold() for t in f.get("tags") or [])
    if "past" in tags and "participle" in tags:
        c["verbes_passe_et_participe"] += 1


def write_outputs(out, edition, stats, pairs, samples):
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "%s_stats.json" % edition), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2, sort_keys=True)
    with gzip.open(os.path.join(out, "%s_pairs.tsv.gz" % edition), "wt", encoding="utf-8") as f:
        for en, fr in sorted(pairs):
            f.write("%s\t%s\n" % (en.replace("\t", " "), fr.replace("\t", " ")))
    with open(os.path.join(out, "%s_samples.json" % edition), "w", encoding="utf-8") as f:
        json.dump(samples, f, ensure_ascii=False, indent=2)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--edition", required=True, choices=["en", "fr"])
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=None,
                    help="s'arrêter après N lignes (essai rapide)")
    args = ap.parse_args(argv)
    stats, pairs, samples = analyse(sys.stdin.buffer, args.edition, args.limit)
    write_outputs(args.out, args.edition, stats, pairs, samples)
    print("édition %s : %d lignes, %d paires" % (
        args.edition, stats.get("lignes", 0), stats["paires_distinctes"]), file=sys.stderr)


if __name__ == "__main__":
    main()
