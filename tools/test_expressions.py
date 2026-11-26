"""Expressions : classement, expressions écrites à la main, index inversé et requêtes SQL du moteur."""
import os
import sqlite3
import tempfile
import unittest

import categories_wiktionnaire as cw
import construire_base as b
import test_requetes

HERE = os.path.dirname(os.path.abspath(__file__))
FREQUENCE = ["the", "go", "hello", "cat", "dog", "run", "ephemeral", "went", "can't"]

TSV = (
    "# commentaire\n"
    "break a leg\tbonne chance ; merde\tcasse une jambe\tidiome\t\tfamilier\tI have a show tonight. Break a leg!\n"
    "how much is it\tcombien ça coûte ?\t\tutile\tachats\t\t\n"
    "kick the bucket\tcasser sa pipe\tdonner un coup de pied dans le seau\tidiome\t\targot\tHe kicked the bucket last year.\n"
    "a rolling stone gathers no moss\tpierre qui roule n'amasse pas mousse\tune pierre qui roule\tproverbe\t\t\t\n"
)


class Expressions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        freq = os.path.join(cls.tmp.name, "f.txt")
        with open(freq, "w") as f:
            f.write("\n".join(FREQUENCE) + "\n")
        cats = os.path.join(cls.tmp.name, "categories")
        os.makedirs(cats)
        with open(os.path.join(cats, "english_idioms.txt"), "w") as f:
            f.write("piece of cake\nkick the bucket\n")
        with open(os.path.join(cats, "english_vulgarities.txt"), "w") as f:
            f.write("by the way\n")  # faux exprès : sert à tester le masquage
        with open(os.path.join(cats, "english_slang.txt"), "w") as f:
            f.write("kick the bucket\n")
        cls.tsv = os.path.join(cls.tmp.name, "expressions_test.tsv")
        with open(cls.tsv, "w", encoding="utf-8") as f:
            f.write(TSV)
        db = os.path.join(cls.tmp.name, "b.db")
        conn = b.ouvrir(db)
        for ed, name in (("en", "sample_base_en.jsonl"), ("fr", "sample_base_fr.jsonl")):
            with open(os.path.join(HERE, name), "rb") as f:
                b.lire(conn, f.readlines(), ed)
        cls.res = b.finaliser(conn, freq, seuil_rang=8, categories=cats,
                              expressions=os.path.join(cls.tmp.name, "expressions_*.tsv"))
        conn.close()
        cls.conn = sqlite3.connect(db)
        cls.sql = test_requetes.lire_requetes()

    @classmethod
    def tearDownClass(cls):
        cls.conn.close()
        cls.tmp.cleanup()

    def q(self, nom, *args):
        return self.conn.execute(self.sql[nom], args).fetchall()

    def type_de(self, mot):
        r = self.conn.execute("SELECT e.type, e.registre, e.curee FROM expressions e JOIN mots m ON m.id = e.mot_id "
                              "WHERE m.mot_recherche = ?", (mot,)).fetchall()
        return r[0] if r else None

    # --- classement
    def test_types(self):
        self.assertEqual(self.type_de("better late than never")[0], "proverbe")
        self.assertEqual(self.type_de("give up")[0], "particule")
        self.assertEqual(self.type_de("go on")[0], "particule")
        self.assertEqual(self.type_de("by the way")[0], "courante")
        self.assertEqual(self.type_de("kick the bucket")[0], "idiome")
        # une catégorie de l'édition anglaise range « piece of cake » (un nom) parmi les idiomes
        self.assertEqual(self.type_de("piece of cake")[0], "idiome")
        # un nom composé n'est pas une expression
        self.assertIsNone(self.type_de("ice cream"))
        # un mot seul non plus
        self.assertIsNone(self.type_de("dog"))

    def test_registres(self):
        self.assertEqual(self.type_de("by the way")[1], "vulgaire")  # via la catégorie (faux exprès)
        self.assertEqual(self.type_de("kick the bucket")[1], "argot")  # écrit à la main : « argot »
        self.assertEqual(self.type_de("piece of cake")[1], "")

    def test_expressions_ecrites_a_la_main(self):
        self.assertEqual(self.res["expressions_curees"], 4)
        self.assertEqual(self.type_de("break a leg"), ("idiome", "familier", 1))
        # « kick the bucket » existait : elle est complétée, pas dupliquée
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM mots WHERE mot_recherche = 'kick the bucket'").fetchone()[0], 1)
        ligne = self.conn.execute("SELECT fr, litteral, exemple FROM expressions e JOIN mots m ON m.id = e.mot_id "
                                  "WHERE m.mot = 'kick the bucket'").fetchone()
        self.assertEqual(ligne[0], "casser sa pipe")
        self.assertIn("seau", ligne[1])
        # les équivalents écrits à la main passent devant dans la liste des équivalents
        eq = self.conn.execute("SELECT t.fr FROM traductions t JOIN mots m ON m.id = t.mot_id "
                               "WHERE m.mot = 'break a leg' ORDER BY t.id").fetchall()
        self.assertEqual([r[0] for r in eq], ["bonne chance", "merde"])

    def test_tsv_invalide_refuse(self):
        faux = os.path.join(self.tmp.name, "expressions_mauvais.tsv")
        with open(faux, "w", encoding="utf-8") as f:
            f.write("seulement une colonne\n")
        conn = b.ouvrir(os.path.join(self.tmp.name, "x.db"))
        with self.assertRaises(ValueError):
            b.charger_expressions_curees(conn, faux)
        conn.close()

    def test_index_inverse(self):
        mots = {r[0] for r in self.conn.execute("SELECT mot FROM expression_mots")}
        self.assertIn("bucket", mots)
        self.assertIn("kick", mots)
        self.assertNotIn("the", mots)  # mot-outil
        self.assertNotIn("a", mots)

    # --- requêtes SQL du moteur
    def test_info_expression(self):
        mot_id = self.conn.execute("SELECT id FROM mots WHERE mot = 'break a leg'").fetchone()[0]
        r = self.q("requeteInfoExpression", mot_id)
        self.assertEqual(r[0][0], "idiome")
        self.assertEqual(r[0][3], "bonne chance")
        self.assertEqual(self.q("requeteInfoExpression", -1), [])

    def test_liste_filtres_et_recherche(self):
        def liste(type_="", theme="", vulgaire=0, motif="", limite=50, decalage=0):
            return [r[1] for r in self.q("requeteExpressions", type_, type_, theme, theme, vulgaire, motif,
                                         "%" + motif + "%", "%" + motif + "%", limite, decalage)]
        tout = liste()
        # les soignées d'abord (ordre alphabétique entre elles quand aucune n'a de rang)
        self.assertEqual(tout[:4], ["a rolling stone gathers no moss", "break a leg", "how much is it", "kick the bucket"])
        self.assertNotIn("better late than never", tout[:4])
        self.assertIn("better late than never", tout)
        self.assertEqual(liste("proverbe"), ["a rolling stone gathers no moss", "better late than never"])
        self.assertEqual(liste("utile", "achats"), ["how much is it"])
        self.assertEqual(liste("utile", "voyage"), [])
        # le vulgaire est masqué par défaut, affiché sur demande
        self.assertNotIn("by the way", tout)
        self.assertIn("by the way", liste(vulgaire=1))
        # recherche en anglais (morceau de l'expression) et en français
        self.assertEqual(liste(motif="bucket"), ["kick the bucket"])
        self.assertEqual(liste(motif="pipe"), ["kick the bucket"])
        self.assertEqual(liste(motif="pierre"), ["a rolling stone gathers no moss"])
        # pagination
        self.assertEqual(len(liste(limite=2)), 2)
        self.assertEqual(liste(limite=2, decalage=2), tout[2:4])

    def test_expressions_avec_un_mot(self):
        r = self.q("requeteExpressionsAvec", "bucket", "bucket", 0, 10)
        self.assertEqual([x[1] for x in r], ["kick the bucket"])
        self.assertEqual(r[0][8], "casser sa pipe")
        # une expression ne se renvoie pas elle-même, et les verbes à particule sont listés à part
        self.assertEqual(self.q("requeteExpressionsAvec", "up", "up", 0, 10), [])
        self.assertEqual(self.q("requeteExpressionsAvec", "give", "give", 0, 10), [])
        # le vulgaire suit le réglage
        self.assertEqual(self.q("requeteExpressionsAvec", "way", "way", 0, 10), [])
        self.assertEqual([x[1] for x in self.q("requeteExpressionsAvec", "way", "way", 1, 10)], ["by the way"])

    def test_expression_du_jour_et_hasard(self):
        n = self.q("requeteNombreExpressionsCurees")[0][0]
        self.assertEqual(n, 3)  # break a leg, kick the bucket, le proverbe ; « how much is it » est « utile »
        vus = {self.q("requeteExpressionCuree", i)[0][1] for i in range(n)}
        self.assertEqual(vus, {"break a leg", "kick the bucket", "a rolling stone gathers no moss"})
        self.assertEqual(self.q("requeteExpressionCuree", n), [])
        hasard = self.q("requeteExpressionsCureesHasard", 2)
        self.assertEqual(len(hasard), 2)
        self.assertTrue(all(r[8] for r in hasard))  # un équivalent français toujours présent


class Categories(unittest.TestCase):
    def test_pagination_et_ecriture(self):
        pages = [
            {"query": {"categorymembers": [{"title": "kick the bucket"}, {"title": "piece of cake"}]},
             "continue": {"cmcontinue": "suite"}},
            {"query": {"categorymembers": [{"title": "spill the beans"}]}},
        ]
        appels = []

        def faux_http(url):
            appels.append(url)
            return pages[len(appels) - 1] if "cmcontinue" in url or len(appels) == 1 else {"query": {"categorymembers": []}}
        self.assertEqual(cw.membres("English idioms", faux_http), ["kick the bucket", "piece of cake", "spill the beans"])
        self.assertIn("Category%3AEnglish_idioms", appels[0])
        self.assertIn("cmcontinue=suite", appels[1])
        self.assertEqual(cw.slug("English ethnic slurs"), "english_ethnic_slurs")

    def test_une_categorie_en_echec_n_arrete_pas_tout(self):
        def http(url):
            if "proverbs" in url:
                raise RuntimeError("503")
            return {"query": {"categorymembers": [{"title": "a b"}]}}
        with tempfile.TemporaryDirectory() as d:
            chiffres = cw.telecharger(d, ["English idioms", "English proverbs"], http)
            self.assertEqual(chiffres, {"English idioms": 1})
            self.assertTrue(os.path.exists(os.path.join(d, "english_idioms.txt")))
            self.assertFalse(os.path.exists(os.path.join(d, "english_proverbs.txt")))


class FichiersCures(unittest.TestCase):
    """Les vrais fichiers data/expressions_*.tsv se chargent sans erreur et restent assez fournis."""

    def test_chargement(self):
        conn = sqlite3.connect(":memory:")
        with open(os.path.join(HERE, "schema.sql"), encoding="utf-8") as f:
            conn.executescript(f.read())
        n = b.charger_expressions_curees(conn, os.path.join(HERE, "data", "expressions_*.tsv"))
        self.assertGreaterEqual(n, 500)
        par_type = dict(conn.execute("SELECT type, COUNT(*) FROM expressions GROUP BY type"))
        for type_ in ("idiome", "utile", "proverbe", "particule"):
            self.assertGreaterEqual(par_type.get(type_, 0), 40, type_)
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM expressions WHERE fr = ''").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main()
