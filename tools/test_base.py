"""Tests de la phase 1 : python3 -m unittest discover -s tools -p "test_*.py"."""
import contextlib
import io
import json
import os
import sqlite3
import tempfile
import unittest

import construire_base as b
import liste_frequence as lf

HERE = os.path.dirname(os.path.abspath(__file__))


def lines(name):
    with open(os.path.join(HERE, name), "rb") as f:
        return f.readlines()


FREQUENCE = ["the", "go", "hello", "cat", "dog", "run", "ephemeral", "went", "can't", "zzzz"]


class Base(unittest.TestCase):
    """Construit une base complète (anglais, français, finalisation) dans un dossier temporaire."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.freq = os.path.join(cls.tmp.name, "frequence.txt")
        with open(cls.freq, "w", encoding="utf-8") as f:
            f.write("\n".join(FREQUENCE) + "\n")
        cls.db = os.path.join(cls.tmp.name, "base.db")
        conn = b.ouvrir(cls.db)
        cls.c_en = b.lire(conn, lines("sample_base_en.jsonl"), "en")
        cls.c_fr = b.lire(conn, lines("sample_base_fr.jsonl"), "fr")
        cls.avant = {t: conn.execute("SELECT COUNT(*) FROM %s" % t).fetchone()[0]
                     for t in ("mots", "traductions")}
        cls.fin = b.finaliser(conn, cls.freq, seuil_rang=8)
        conn.close()
        cls.conn = sqlite3.connect(cls.db)

    @classmethod
    def tearDownClass(cls):
        cls.conn.close()
        cls.tmp.cleanup()

    def q(self, sql, *args):
        return self.conn.execute(sql, args).fetchall()

    def mot(self, word, nature):
        row = self.q("SELECT id FROM mots WHERE mot = ? AND nature = ?", word, nature)
        return row[0][0] if row else None

    def equivalents(self, word, nature):
        return {r[0]: r[1] for r in self.q(
            "SELECT fr, source FROM traductions WHERE mot_id = ?", self.mot(word, nature))}

    # --- lecture
    def test_compteurs_de_lecture(self):
        self.assertEqual(self.c_en["illisibles"], 1)
        self.assertEqual(self.c_en["ignorees_sans_contenu"], 1)   # « vide »
        self.assertEqual(self.c_en["renvois"], 2)                 # went, gone
        self.assertEqual(self.c_fr["francais_avec_traduction"], 5)

    def test_langues_et_natures_ignorees(self):
        self.assertIsNone(self.mot("casa", "noun"))
        self.assertIsNone(self.mot("a", "character"))
        self.assertIsNone(self.mot("vide", "noun"))

    def test_casse_distincte_a_la_lecture_anglaise(self):
        self.assertEqual(self.equivalents("Turkey", "name"), {"Turquie": "en"})
        self.assertEqual(self.equivalents("turkey", "noun"), {"dinde": "en"})

    # --- fusion
    def test_traduction_inversee_ajoutee_sur_mot_existant(self):
        eq = self.equivalents("hello", "intj")
        self.assertEqual(eq["bonjour"], "en+fr")
        self.assertEqual(eq["salut"], "en")
        # « good morning » n'existait pas côté anglais : il naît de l'édition française
        self.assertEqual(self.equivalents("good morning", "intj"), {"bonjour": "fr"})

    def test_inversee_tolere_la_casse_et_la_nature_francaise(self):
        # « Dog » (édition française, nature « nom ») rejoint « dog » / noun
        eq = self.equivalents("dog", "noun")
        self.assertEqual(eq["chien"], "en+fr")
        self.assertIn("chienne", eq)
        self.assertIsNone(self.mot("Dog", "noun"))

    def test_mot_cree_par_l_edition_francaise(self):
        self.assertEqual(self.equivalents("cat", "noun"), {"chat": "fr"})
        run_v = self.q("SELECT src_en, src_fr FROM mots WHERE mot = 'run' AND nature = 'verb'")
        self.assertEqual(run_v, [(0, 1)])
        # « course » est un nom : il ne se colle pas au verbe « run »
        self.assertEqual(self.equivalents("run", "verb"), {"courir": "fr"})
        self.assertEqual(self.equivalents("run", "noun"), {"course": "fr"})

    def test_sources_des_mots(self):
        self.assertEqual(self.q("SELECT src_en, src_fr FROM mots WHERE mot = 'go' AND nature = 'verb'"),
                         [(1, 1)])
        self.assertEqual(self.q("SELECT src_en, src_fr FROM mots WHERE mot = 'hello'"), [(1, 1)])

    def test_genre_des_traductions(self):
        genres = dict(self.q("SELECT fr, genre FROM traductions WHERE mot_id = ?", self.mot("dog", "noun")))
        self.assertEqual(genres["chienne"], "f")
        self.assertEqual(genres["chien"], "m")  # ancienne clé `code` acceptée

    def test_langues_etrangeres_ignorees_dans_les_traductions(self):
        self.assertNotIn("ir", self.equivalents("go", "verb"))
        self.assertNotIn("guten Tag", self.equivalents("hello", "intj"))

    # --- contenu d'une fiche
    def test_sens_et_exemples(self):
        sens = self.q("SELECT ordre, definition, contexte, etiquettes, exemple FROM sens "
                      "WHERE mot_id = ? ORDER BY ordre", self.mot("go", "verb"))
        self.assertEqual(sens[0], (1, "To move through space.", "", "intransitive", "I go to school."))
        self.assertEqual(sens[1][:3], (2, "To depart.", "To leave."))

    def test_definitions_francaises_separees(self):
        defs = [r[0] for r in self.q("SELECT texte FROM definitions_fr WHERE mot_id = ?", self.mot("go", "verb"))]
        self.assertEqual(defs, ["Aller."])
        self.assertEqual(self.q("SELECT COUNT(*) FROM sens WHERE mot_id = ?", self.mot("inconnu", "noun")),
                         [(0,)])

    def test_formes(self):
        formes = {r[0] for r in self.q("SELECT forme FROM formes WHERE mot_id = ?", self.mot("go", "verb"))}
        self.assertEqual(formes, {"goes", "went", "gone"})  # ni « go » lui-même ni les balises de tableau

    def test_renvois(self):
        self.assertEqual(self.q("SELECT forme_norm, lemme_norm FROM renvois ORDER BY forme_norm"),
                         [("gone", "go"), ("went", "go")])  # « geese -> goose » : goose absent -> supprimé

    # --- audio
    def test_accents_de_l_audio(self):
        groupes = dict(self.q("SELECT fichier, accent FROM audio WHERE mot_id = ?", self.mot("go", "verb")))
        self.assertEqual(groupes["En-us-go.ogg"], "us")
        self.assertEqual(groupes["En-uk-go.ogg"], "uk")      # Southern-England : bien britannique
        self.assertEqual(groupes["En-au-go.ogg"], "au")
        self.assertEqual(groupes["En-us-go2.ogg"], "us")     # sans balise : d'après le nom
        hello = dict(self.q("SELECT fichier, accent FROM audio WHERE mot_id = ?", self.mot("hello", "intj")))
        self.assertEqual(hello["En-uk-hello.ogg"], "uk")
        self.assertEqual(hello["LL-Q1860 (eng)-Someone-hello.wav"], "autre")

    def test_audio_fusionne_sans_doublon(self):
        n = self.q("SELECT COUNT(*) FROM audio WHERE mot_id = ? AND fichier = 'En-us-go.ogg'",
                   self.mot("go", "verb"))
        self.assertEqual(n, [(1,)])

    def test_transcription(self):
        self.assertEqual(self.q("SELECT accent, api FROM prononciations WHERE mot_id = ?",
                                self.mot("go", "verb")), [("uk", "/ɡəʊ/")])

    # --- finalisation
    def test_elagage(self):
        self.assertIsNone(self.mot("obscureword", "noun"))           # sans équivalent, non courant
        self.assertIsNotNone(self.mot("the", "det"))                  # sans équivalent mais rang 1
        self.assertIsNotNone(self.mot("ephemeral", "adj"))            # définition française
        self.assertIsNotNone(self.mot("inconnu", "noun"))             # définition française
        self.assertEqual(self.fin["mots_avant_elagage"] - self.fin["mots_elagues"],
                         self.q("SELECT COUNT(*) FROM mots")[0][0])
        self.assertGreaterEqual(self.fin["mots_elagues"], 1)
        # les lignes dépendantes disparaissent avec le mot
        self.assertEqual(self.q("SELECT COUNT(*) FROM sens WHERE mot_id NOT IN (SELECT id FROM mots)"), [(0,)])

    def test_rangs(self):
        self.assertEqual(self.q("SELECT rang FROM mots WHERE mot = 'go' AND nature = 'verb'"), [(2,)])
        self.assertEqual(self.q("SELECT rang FROM mots WHERE mot = 'Turkey'"), [(None,)])

    def test_contractions_et_meta(self):
        self.assertGreater(self.fin["contractions"], 50)
        self.assertEqual(self.q("SELECT developpe FROM contractions WHERE forme = ?", "can't"),
                         [("cannot",)])
        meta = dict(self.q("SELECT cle, valeur FROM meta"))
        self.assertEqual(meta["version_schema"], "1")
        self.assertIn("CC BY-SA 4.0", meta["licence"])

    def test_renvois_orphelins_supprimes(self):
        self.assertEqual(self.q("SELECT COUNT(*) FROM renvois WHERE lemme_norm = 'goose'"), [(0,)])

    # --- rapport
    def test_rapport(self):
        r = b.rapport(self.conn, self.freq)
        self.assertEqual(r["anomalies"]["renvois_orphelins"], 0)
        self.assertEqual(r["anomalies"]["mots_sans_contenu"], 0)
        self.assertEqual(r["audio_par_accent"]["us"], 3)   # En-us-go, En-us-go2, En-us-hello
        self.assertEqual(r["mots_avec_audio_uk"], 2)       # go, hello
        self.assertEqual(r["traductions_par_source"].get("en+fr"), 2)  # bonjour, chien
        cov = r["couverture"][str(len(FREQUENCE))]
        self.assertEqual(cov["mots_evalues"], 10)
        # go, hello, cat, dog, run, went (via go), can't (contraction) ; the/ephemeral : définition seule
        self.assertEqual(cov["equivalent"], 7)
        self.assertEqual(cov["definition_seule"], 2)
        self.assertEqual(cov["absent"], 1)
        self.assertTrue(r["bloquantes"])  # 70 % < 95 %
        md = b.rapport_markdown(r, 1234)
        self.assertIn("BLOQUANT", md)
        self.assertIn("Mots courants", md)

    def test_rapport_sans_frequence_ni_blocage(self):
        r = b.rapport(self.conn)
        self.assertNotIn("couverture", r)
        self.assertEqual(r["bloquantes"], [])
        self.assertIn("Aucune anomalie bloquante", b.rapport_markdown(r))

    def test_base_vide_est_bloquante(self):
        with tempfile.TemporaryDirectory() as d:
            conn = b.ouvrir(os.path.join(d, "vide.db"))
            self.assertIn("la base est vide", b.rapport(conn)["bloquantes"])
            conn.close()


class Divers(unittest.TestCase):
    def test_pliage_des_accents(self):
        self.assertEqual(b.fold("Café Œuf"), "cafe oeuf")
        self.assertEqual(b.norm("  Don’t "), "don't")

    def test_groupes_d_accent(self):
        self.assertEqual(b.accent_group({"southern-england"}, None), "uk")
        self.assertEqual(b.accent_group(set(), "En-au-x.ogg"), "au")
        self.assertEqual(b.accent_group({"canada"}, "x.ogg"), "autre")
        self.assertEqual(b.accent_group({"us", "uk"}, None), "us")

    def test_natures(self):
        self.assertEqual(b.normaliser_nature("Nom propre"), "name")
        self.assertEqual(b.normaliser_nature("adjective"), "adj")
        self.assertEqual(b.normaliser_nature(None), "?")

    def test_edition_inconnue(self):
        with tempfile.TemporaryDirectory() as d:
            conn = b.ouvrir(os.path.join(d, "x.db"))
            with self.assertRaises(ValueError):
                b.lire(conn, [], "de")
            conn.close()

    def test_contractions_mal_formees(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "c.tsv")
            with open(path, "w", encoding="utf-8") as f:
                f.write("# commentaire\ncan't\tcannot\n")
            conn = b.ouvrir(os.path.join(d, "x.db"))
            with self.assertRaises(ValueError):
                b.charger_contractions(conn, path)
            conn.close()

    def test_fichier_de_contractions_du_depot(self):
        with tempfile.TemporaryDirectory() as d:
            conn = b.ouvrir(os.path.join(d, "x.db"))
            n = b.charger_contractions(conn, b.CONTRACTIONS)
            self.assertEqual(n, conn.execute("SELECT COUNT(*) FROM contractions").fetchone()[0])
            conn.close()

    def test_liste_de_frequence(self):
        self.assertEqual(lf.clean_words(["The", "the", "don’t", "3d", "e-mail", "ok"]),
                         ["the", "don't", "ok"])

    def test_ligne_de_commande_complete(self):
        with tempfile.TemporaryDirectory() as d:
            db = os.path.join(d, "b.db")
            freq = os.path.join(d, "f.txt")
            with open(freq, "w", encoding="utf-8") as f:
                f.write("go\nhello\n")
            for ed, name in (("en", "sample_base_en.jsonl"), ("fr", "sample_base_fr.jsonl")):
                with open(os.path.join(HERE, name), "rb") as src:
                    stdin = io.TextIOWrapper(io.BytesIO(src.read()))
                    real = b.sys.stdin
                    b.sys.stdin = stdin
                    try:
                        with contextlib.redirect_stderr(io.StringIO()):
                            self.assertEqual(b.main(["lire", "--db", db, "--edition", ed]), 0)
                    finally:
                        b.sys.stdin = real
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(b.main(["finaliser", "--db", db, "--frequence", freq]), 0)
            with contextlib.redirect_stdout(io.StringIO()):
                code = b.main(["rapport", "--db", db, "--frequence", freq, "--out", d, "--strict"])
            self.assertEqual(code, 0)
            with open(os.path.join(d, "rapport_base.json"), encoding="utf-8") as f:
                self.assertGreater(json.load(f)["mots"], 5)


if __name__ == "__main__":
    unittest.main()
