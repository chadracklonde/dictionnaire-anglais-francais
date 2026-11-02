#!/usr/bin/env python3
"""Prépare les assets de l'application Flutter à partir de la base SQLite.

Découpe la base en morceaux de 20 Mo (app/assets/db/part_000, ...) avec un manifest.json
(version, nombre de morceaux, taille, chiffres), pour que l'application la recopie au
premier lancement sans la charger entière en mémoire.

    python3 tools/build_assets.py dictionnaire-en-fr.db [--chunk-mb 20] [--out app/assets/db]
"""
import argparse
import json
import shutil
import sqlite3
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def construire(db, out, chunk_mb=20, jour=None):
    """Écrit les morceaux et le manifest dans `out` ; renvoie le manifest."""
    db = Path(db)
    out = Path(out)
    if not db.exists():
        raise SystemExit("Fichier introuvable : %s" % db)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    taille_morceau = chunk_mb * 1_000_000
    morceaux = 0
    with db.open("rb") as src:
        while True:
            data = src.read(taille_morceau)
            if not data:
                break
            (out / ("part_%03d" % morceaux)).write_bytes(data)
            morceaux += 1

    taille = db.stat().st_size
    con = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
    try:
        manifest = {
            "version": "%s-%d" % ((jour or date.today()).isoformat(), taille),
            "parts": morceaux,
            "size": taille,
            "words": con.execute("SELECT COUNT(*) FROM mots").fetchone()[0],
            "verbs": con.execute("SELECT COUNT(*) FROM mots WHERE nature = 'verb'").fetchone()[0],
            "translations": con.execute("SELECT COUNT(*) FROM traductions").fetchone()[0],
        }
    finally:
        con.close()
    (out / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    return manifest


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("db")
    ap.add_argument("--chunk-mb", type=int, default=20)
    ap.add_argument("--out", default=str(ROOT / "app" / "assets" / "db"))
    args = ap.parse_args()
    m = construire(args.db, args.out, args.chunk_mb)
    print("%d mots, %d verbes, %d traductions" % (m["words"], m["verbs"], m["translations"]))
    print("%d morceaux (%.1f Mo) -> %s" % (m["parts"], m["size"] / 1e6, args.out))


if __name__ == "__main__":
    main()
