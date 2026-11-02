"""Vérifie contre une vraie base les requêtes SQL du moteur Dart (engine/lib/src/requetes.dart)
et la normalisation partagée (engine/test/pliage.tsv)."""
import os
import re
import sqlite3
import tempfile
import unittest

import construire_base as b

HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.join(HERE, "..", "engine")
FREQUENCE = ["the", "go", "hello", "cat", "dog", "run", "ephemeral", "went", "can't"]


def lire_requetes():
    with open(os.path.join(ENGINE, "lib", "src", "requetes.dart"), encoding="utf-8") as f:
        source = f.read()
    return dict(re.findall(r"^const String (\w+) = '''(.*?)''';", source, re.S | re.M))


class Requetes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        freq = os.path.join(cls.tmp.name, "f.txt")
        with open(freq, "w", encoding="utf-8") as f:
            f.write("\n".join(FREQUENCE) + "\n")
        db = os.path.join(cls.tmp.name, "b.db")
        conn = b.ouvrir(db)
        for ed, name in (("en", "sample_base_en.jsonl"), ("fr", "sample_base_fr.jsonl")):
            with open(os.path.join(HERE, name), "rb") as f:
                b.lire(conn, f.readlines(), ed)
        b.finaliser(conn, freq, seuil_rang=8)
        conn.close()
        cls.conn = sqlite3.connect(db)
        cls.sql = lire_requetes()

    @classmethod
    def tearDownClass(cls):
        cls.conn.close()
        cls.tmp.cleanup()

    def run_q(self, nom, *args):
        return self.conn.execute(self.sql[nom], args).fetchall()

    def mot_id(self, mot, nature):
        return self.conn.execute("SELECT id FROM mots WHERE mot = ? AND nature = ?", (mot, nature)).fetchone()[0]

    def test_toutes_les_requetes_sont_lues(self):
        attendues = {
            "requeteMotsParRecherche", "requeteLemmesDeForme", "requeteContraction", "requeteEquivalents",
            "requeteSens", "requeteDefinitionsFr", "requeteFormes", "requeteAudio",
            "requetePrononciations", "requeteAnglaisParFrancais", "requeteSuggestionsAnglais",
            "requeteSuggestionsFrancais",
            "requeteIndexAnglais", "requeteChiffres", "requeteMeta"}
        self.assertEqual(set(self.sql), attendues)
        for nom, sql in self.sql.items():
            self.assertNotIn("$", sql, nom)

    def test_nombre_de_parametres(self):
        for nom, sql in self.sql.items():
            n = sql.count("?")
            self.conn.execute(sql, [1] * n).fetchall()  # n'échoue pas si le SQL est valide

    def test_mots_par_recherche(self):
        rows = self.run_q("requeteMotsParRecherche", "go")
        self.assertEqual([r[1:3] for r in rows], [("go", "verb"), ("go", "noun")])
        self.assertEqual(self.run_q("requeteMotsParRecherche", "zzz"), [])
        # « Turkey » (nom propre) et « turkey » partagent la forme de recherche
        self.assertEqual(len(self.run_q("requeteMotsParRecherche", "turkey")), 2)

    def test_lemmes_de_forme(self):
        self.assertEqual([r[1] for r in self.run_q("requeteLemmesDeForme", "went")], ["go"])
        self.assertEqual([r[1] for r in self.run_q("requeteLemmesDeForme", "goes")], ["go"])
        self.assertEqual([(r[1], r[4]) for r in self.run_q("requeteLemmesDeForme", "could")], [("can", "conditional")])

    def test_contraction(self):
        self.assertEqual(self.run_q("requeteContraction", "can't")[0][1], "cannot")
        self.assertEqual(self.run_q("requeteContraction", "xyz"), [])

    def test_equivalents_les_mieux_confirmes_d_abord(self):
        rows = self.run_q("requeteEquivalents", self.mot_id("dog", "noun"))
        self.assertEqual([(r[0], r[3]) for r in rows], [("chien", "en+fr"), ("chienne", "en")])

    def test_sens_formes_audio_prononciations(self):
        go = self.mot_id("go", "verb")
        self.assertEqual([r[0] for r in self.run_q("requeteSens", go)], [1, 2])
        self.assertEqual({r[0] for r in self.run_q("requeteFormes", go)}, {"goes", "went", "gone"})
        self.assertEqual(self.run_q("requeteDefinitionsFr", go), [("Aller.",)])
        accents = [r[1] for r in self.run_q("requeteAudio", go)]
        self.assertEqual(accents[0], "us")
        self.assertEqual(sorted(accents), sorted(["us", "us", "uk", "au"]))
        self.assertEqual(self.run_q("requetePrononciations", go), [("uk", "/ɡəʊ/")])

    def test_francais_vers_anglais(self):
        rows = self.run_q("requeteAnglaisParFrancais", "chien", 10)
        self.assertEqual([(r[1], r[7]) for r in rows], [("dog", "en+fr")])
        self.assertEqual([r[1] for r in self.run_q("requeteAnglaisParFrancais", "chat", 10)], ["cat"])
        # sans accent : « Turquie » ne change pas, mais la recherche est pliée côté base
        self.assertEqual([r[1] for r in self.run_q("requeteAnglaisParFrancais", "turquie", 10)], ["Turkey"])
        self.assertEqual(len(self.run_q("requeteAnglaisParFrancais", "bonjour", 1)), 1)

    def test_suggestions(self):
        def borne(p):
            return p + "￿"
        self.assertEqual([r[0] for r in self.run_q("requeteSuggestionsAnglais", "he", borne("he"), 5)], ["hello"])
        self.assertIn("turkey", [r[0] for r in self.run_q("requeteSuggestionsAnglais", "tu", borne("tu"), 5)])
        self.assertEqual([r[0] for r in self.run_q("requeteSuggestionsFrancais", "ch", borne("ch"), 5)],
                         ["chat", "chien", "chienne"])

    def test_index_chiffres_meta(self):
        page = self.run_q("requeteIndexAnglais", "", 3)
        self.assertEqual(len(page), 3)
        cles = [r[1] for r in page]
        self.assertEqual(cles, sorted(cles))
        suite = self.run_q("requeteIndexAnglais", cles[-1], 3)
        self.assertTrue(all(r[1] > cles[-1] for r in suite))
        mots, traductions, verbes, audio = self.run_q("requeteChiffres")[0]
        self.assertGreater(mots, 5)
        self.assertGreater(traductions, 5)
        self.assertGreater(verbes, 0)
        self.assertGreater(audio, 3)
        self.assertEqual(dict(self.run_q("requeteMeta"))["version_schema"], "1")

    def test_les_recherches_principales_utilisent_un_index(self):
        cas = [
            ("requeteMotsParRecherche", ("go",)),
            ("requeteLemmesDeForme", ("went",)),
            ("requeteAnglaisParFrancais", ("chien", 10)),
            ("requeteSuggestionsAnglais", ("he", "he￿", 5)),
            ("requeteSuggestionsFrancais", ("ch", "ch￿", 5)),
        ]
        for nom, args in cas:
            plan = " ".join(r[3] for r in self.conn.execute("EXPLAIN QUERY PLAN " + self.sql[nom], args))
            self.assertIn("INDEX", plan, "%s : %s" % (nom, plan))


class Pliage(unittest.TestCase):
    def test_cas_partages_avec_dart(self):
        n = 0
        with open(os.path.join(ENGINE, "test", "pliage.tsv"), encoding="utf-8") as f:
            for ligne in f:
                ligne = ligne.rstrip("\n")
                if not ligne or ligne.startswith("#"):
                    continue
                entree, attendu = ligne.split("\t")
                self.assertEqual(" ".join(b.fold(entree).split()), attendu, entree)
                n += 1
        self.assertGreater(n, 10)


if __name__ == "__main__":
    unittest.main()
