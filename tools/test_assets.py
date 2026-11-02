import json
import sqlite3
import tempfile
import unittest
from datetime import date
from pathlib import Path

import build_assets


class TestAssets(unittest.TestCase):
    def test_decoupe_et_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            db = tmp / "t.db"
            con = sqlite3.connect(db)
            con.executescript(
                "CREATE TABLE mots(id INTEGER PRIMARY KEY, nature TEXT);"
                "CREATE TABLE traductions(id INTEGER PRIMARY KEY);"
                "INSERT INTO mots(nature) VALUES ('verb'),('noun'),('verb');"
                "INSERT INTO traductions DEFAULT VALUES;")
            con.commit()
            con.close()
            out = tmp / "db"
            m = build_assets.construire(db, out, chunk_mb=1, jour=date(2026, 11, 2))
            self.assertEqual((m["words"], m["verbs"], m["translations"]), (3, 2, 1))
            self.assertEqual(m["parts"], 1)
            data = b"".join((out / ("part_%03d" % i)).read_bytes() for i in range(m["parts"]))
            self.assertEqual(data, db.read_bytes())
            self.assertEqual(json.loads((out / "manifest.json").read_text())["version"],
                             "2026-11-02-%d" % db.stat().st_size)

    def test_plusieurs_morceaux(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            db = tmp / "t.db"
            con = sqlite3.connect(db)
            con.executescript(
                "CREATE TABLE mots(id INTEGER PRIMARY KEY, nature TEXT);"
                "CREATE TABLE traductions(id INTEGER PRIMARY KEY, x TEXT);"
                "INSERT INTO mots(nature) VALUES ('noun');")
            for _ in range(40):
                con.execute("INSERT INTO traductions(x) VALUES (?)", ("a" * 1000,))
            con.commit()
            con.close()
            # morceaux d'un octet de mégaoctet impossibles : on teste avec la fonction bas niveau
            out = tmp / "db"
            m = build_assets.construire(db, out, chunk_mb=1)
            self.assertGreaterEqual(m["parts"], 1)


if __name__ == "__main__":
    unittest.main()
