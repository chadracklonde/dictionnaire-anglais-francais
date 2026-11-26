"""Tests de l'audio américain, sans réseau : python3 -m unittest discover -s tools -p "test_*.py"."""
import json
import os
import sqlite3
import tempfile
import unittest

import audio_us as a
import construire_base as b

HERE = os.path.dirname(os.path.abspath(__file__))


def faux_commons(titres_infos):
    """Réponse de l'API Commons pour des titres déjà connus (formatversion=2)."""
    def http(url):
        import urllib.parse
        titres = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["titles"][0].split("|")
        pages = []
        for t in titres:
            info = titres_infos.get(t)
            if info is None:
                pages.append({"title": t, "missing": True})
            else:
                pages.append({"title": t, "imageinfo": [info]})
        return {"query": {"pages": pages}}
    return http


def info(taille, licence, auteur="<a href='x'>Alice &amp; Bob</a>", mime="audio/ogg"):
    return {
        "url": "https://upload.example/x", "size": taille, "mime": mime,
        "descriptionurl": "https://commons.example/File:x",
        "extmetadata": {"Artist": {"value": auteur}, "LicenseShortName": {"value": licence},
                        "LicenseUrl": {"value": "https://cc.example/by-sa/4.0"}},
    }


class Audio(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        freq = os.path.join(cls.tmp.name, "f.txt")
        with open(freq, "w") as f:
            f.write("the\ngo\nhello\ncat\ndog\n")
        cls.db = os.path.join(cls.tmp.name, "b.db")
        conn = b.ouvrir(cls.db)
        for ed, n in (("en", "sample_base_en.jsonl"), ("fr", "sample_base_fr.jsonl")):
            with open(os.path.join(HERE, n), "rb") as f:
                b.lire(conn, f.readlines(), ed)
        b.finaliser(conn, freq, seuil_rang=8, expressions=None)
        conn.close()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_un_enregistrement_americain_par_mot(self):
        conn = sqlite3.connect(self.db)
        sel = a.selectionner(conn)
        conn.close()
        fichiers = [s["fichier"] for s in sel]
        self.assertEqual(fichiers, ["En-us-go.ogg", "En-us-hello.ogg"])  # pas En-us-go2, pas uk
        self.assertEqual([s["rang"] for s in sel], [2, 3])

    def test_licences(self):
        for ok in ("CC BY-SA 4.0", "CC BY 3.0", "CC0", "Public domain", "CC BY-SA 3.0 de"):
            self.assertTrue(a.licence_acceptable(ok), ok)
        for non in ("CC BY-NC 4.0", "CC BY-ND 3.0", "CC BY-NC-SA 3.0", "GFDL", "", "Copyrighted free use"):
            self.assertFalse(a.licence_acceptable(non), non)

    def test_chaine_complete(self):
        octets = b"x" * 1000
        http_meta = faux_commons({
            "File:En-us-go.ogg": info(1000, "CC BY-SA 4.0"),
            "File:En-us-hello.ogg": info(1000, "CC BY-NC 4.0"),
        })
        sortie = os.path.join(self.tmp.name, "sortie")
        index, texte = a.executer(self.db, sortie, rang_coeur=2, http_meta=http_meta,
                                  http_fichier=lambda url: octets, pause=0, workers=2)
        # go (rang 2) dans le cœur ; hello refusé pour sa licence
        self.assertEqual(list(index["fichiers"]), ["En-us-go.ogg"])
        f = index["fichiers"]["En-us-go.ogg"]
        self.assertEqual((f["p"], f["l"], f["a"]), ("audio_us_core", "CC BY-SA 4.0", "Alice & Bob"))
        self.assertTrue(os.path.exists(os.path.join(sortie, "audio_us_core", "En-us-go.ogg")))
        self.assertEqual(index["packs"]["audio_us_core"], {"fichiers": 1, "octets": 1000, "coeur": True})
        self.assertIn("licence 1", texte)
        with open(os.path.join(sortie, "audio_index.json"), encoding="utf-8") as fh:
            self.assertEqual(json.load(fh)["fichiers"]["En-us-go.ogg"]["f"], "En-us-go.ogg")

    def test_decoupage_en_packs(self):
        gardes = [{"fichier": "c%d.ogg" % i, "mot": "c", "rang": i, "taille": 400_000} for i in (1, 2)]
        gardes += [{"fichier": "e%d.ogg" % i, "mot": "e", "rang": 100 + i, "taille": 600_000} for i in range(5)]
        gardes += [{"fichier": "n.ogg", "mot": "n", "rang": None, "taille": 100_000}]
        for g in gardes:
            g.update(auteur="", licence="CC0", licence_url="", page="")
        packs = a.planifier(gardes, rang_coeur=10, taille_pack_mo=1)  # 1 Mo par pack
        self.assertEqual([len(v) for v in packs.values()], [2, 1, 1, 1, 1, 2])  # le fichier sans rang rejoint le dernier pack s'il reste de la place
        self.assertEqual(list(packs)[:3], ["us_core", "us_1", "us_2"])
        # le fichier sans rang va dans un pack facultatif, jamais dans le cœur
        self.assertNotIn("n.ogg", [g["fichier"] for g in packs["us_core"]])

    def test_ecartes_et_echecs(self):
        cand = [{"fichier": f, "mot": f, "rang": i} for i, f in enumerate(["a.ogg", "b.ogg", "c.ogg", "d.ogg"], 1)]
        infos = {
            "a.ogg": {"url": "u", "taille": 10, "mime": "audio/ogg", "licence": "CC0", "auteur": "", "licence_url": "", "page": ""},
            "b.ogg": {"url": "u", "taille": 10_000_000, "mime": "audio/ogg", "licence": "CC0", "auteur": "", "licence_url": "", "page": ""},
            "c.ogg": {"url": "u", "taille": 10, "mime": "image/png", "licence": "CC0", "auteur": "", "licence_url": "", "page": ""},
        }
        gardes, refus = a.filtrer(cand, infos)
        self.assertEqual([g["fichier"] for g in gardes], ["a.ogg"])
        self.assertEqual(dict(refus), {"taille": 1, "pas_audio": 1, "introuvable": 1})
        packs = a.planifier(gardes)
        sortie = os.path.join(self.tmp.name, "echec")

        def casse(url):
            raise RuntimeError("503")
        echecs = a.telecharger(packs, sortie, http=casse, workers=1, pause=0)
        self.assertEqual(len(echecs), 1)
        index = a.construire_index(packs, echecs)
        self.assertEqual(index["fichiers"], {})

    def test_budget_de_temps_depasse(self):
        gardes = [{"fichier": "a.ogg", "mot": "a", "rang": 1, "taille": 3, "url": "u", "auteur": "",
                   "licence": "CC0", "licence_url": "", "page": ""}]
        packs = a.planifier(gardes)
        sortie = os.path.join(self.tmp.name, "budget")
        appels = []
        echecs = a.telecharger(packs, sortie, http=lambda u: appels.append(u) or b"abc",
                               workers=1, pause=0, budget_s=-1, journal=None)
        self.assertEqual(echecs, [("a.ogg", "temps écoulé")])
        self.assertEqual(appels, [])

    def test_pack_vide_absent_de_l_index_et_du_disque(self):
        gardes = [{"fichier": "c.ogg", "mot": "c", "rang": 1, "taille": 3, "url": "u", "auteur": "",
                   "licence": "CC0", "licence_url": "", "page": ""},
                  {"fichier": "e.ogg", "mot": "e", "rang": 99999, "taille": 3, "url": "u", "auteur": "",
                   "licence": "CC0", "licence_url": "", "page": ""}]
        packs = a.planifier(gardes, rang_coeur=10)
        sortie = os.path.join(self.tmp.name, "videpack")

        def un_seul(url):
            return b"abc"
        # le deuxième fichier n'est pas téléchargé : budget épuisé dès le départ pour lui seul
        etat = {"n": 0}

        def http(url):
            etat["n"] += 1
            if etat["n"] > 1:
                raise RuntimeError("503")
            return b"abc"
        echecs = a.telecharger(packs, sortie, http=http, workers=1, pause=0, journal=None)
        self.assertEqual(len(echecs), 1)
        index = a.construire_index(packs, echecs)
        self.assertEqual(list(index["packs"]), ["audio_us_core"])  # pas audio_us_1
        self.assertTrue(os.path.isdir(os.path.join(sortie, "audio_us_core")))
        self.assertFalse(os.path.exists(os.path.join(sortie, "audio_us_1")))

    def test_rang_max(self):
        octets = b"x" * 10
        http_meta = faux_commons({
            "File:En-us-go.ogg": info(10, "CC0"),
            "File:En-us-hello.ogg": info(10, "CC0"),
        })
        sortie = os.path.join(self.tmp.name, "rangmax")
        index, _ = a.executer(self.db, sortie, rang_coeur=2, rang_max=2, http_meta=http_meta,
                              http_fichier=lambda url: octets, pause=0, workers=1)
        self.assertEqual(list(index["fichiers"]), ["En-us-go.ogg"])  # hello (rang 3) écarté

    def test_noms_locaux(self):
        self.assertEqual(a.nom_local("LL-Q1860 (eng)-Someone-hello.wav"), "LL-Q1860__eng_-Someone-hello.wav")
        self.assertEqual(a.nom_local("En-us-go.ogg"), "En-us-go.ogg")


if __name__ == "__main__":
    unittest.main()
