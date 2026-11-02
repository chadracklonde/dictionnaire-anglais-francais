"""Tests de la phase 0 : python3 -m unittest discover -s tools -p "test_*.py"."""
import contextlib
import gzip
import io
import json
import os
import tempfile
import unittest

import analyse_wiktionnaire as a
import couverture_frequence as cf
import rapport_phase0 as r

HERE = os.path.dirname(os.path.abspath(__file__))


def lines(name):
    with open(os.path.join(HERE, name), "rb") as f:
        return f.readlines()


class AnalyseEn(unittest.TestCase):
    def setUp(self):
        self.stats, self.pairs, self.samples = a.analyse(lines("sample_en.jsonl"), "en")

    def test_entrees_anglaises_seulement(self):
        self.assertEqual(self.stats["lignes"], 6)
        self.assertEqual(self.stats["entrees_anglaises"], 4)

    def test_traductions_francaises(self):
        self.assertEqual(self.stats["anglais_avec_traduction_fr"], 2)
        self.assertEqual(self.stats["traductions_fr"], 4)  # l'espagnol est ignoré
        self.assertEqual(self.stats["traductions_fr_avec_sens"], 3)
        self.assertIn(("go", "aller"), self.pairs)
        self.assertIn(("hello", "salut"), self.pairs)
        self.assertEqual(len(self.pairs), 4)

    def test_audio_et_accents(self):
        self.assertEqual(self.stats["anglais_avec_audio"], 2)
        self.assertEqual(self.stats["anglais_audio_us"], 2)
        self.assertEqual(self.stats["anglais_audio_uk"], 1)
        self.assertEqual(self.stats["fichiers_audio_distincts"], 3)
        self.assertEqual(self.stats["anglais_avec_api"], 1)
        self.assertTrue(all(u.startswith("https://") for u in self.stats["urls_audio_echantillon"]))

    def test_verbes_et_formes(self):
        self.assertEqual(self.stats["verbes"], 2)
        self.assertEqual(self.stats["verbes_avec_formes"], 1)
        self.assertEqual(self.stats["verbes_passe_et_participe"], 1)
        self.assertEqual(self.stats["anglais_formes_renvoi"], 1)

    def test_ancienne_cle_code_pour_les_traductions(self):
        ligne = (b'{"word": "cat", "lang_code": "en", "pos": "noun", '
                 b'"senses": [{"glosses": ["A feline."]}], '
                 b'"translations": [{"code": "fr", "lang": "French", "word": "chat", "sense": "animal"}]}')
        stats, pairs, _ = a.analyse([ligne], "en")
        self.assertEqual(stats["traductions_fr"], 1)
        self.assertIn(("cat", "chat"), pairs)

    def test_limite(self):
        stats, _, _ = a.analyse(lines("sample_en.jsonl"), "en", limit=2)
        self.assertEqual(stats["lignes"], 2)

    def test_ligne_illisible(self):
        stats, _, _ = a.analyse([b"{pas du json", b""], "en")
        self.assertEqual(stats["lignes_illisibles"], 1)


class AnalyseFr(unittest.TestCase):
    def setUp(self):
        self.stats, self.pairs, self.samples = a.analyse(lines("sample_fr.jsonl"), "fr")

    def test_paires_inversees(self):
        self.assertEqual(self.stats["entrees_francaises"], 3)
        self.assertEqual(self.stats["francais_avec_traduction_en"], 2)
        self.assertEqual(self.stats["traductions_en"], 3)  # l'allemand est ignoré
        self.assertIn(("hello", "bonjour"), self.pairs)
        self.assertIn(("cat", "chat"), self.pairs)

    def test_anglais_defini_en_francais(self):
        self.assertEqual(self.stats["entrees_anglaises"], 2)
        self.assertEqual(self.stats["anglais_defini_en_francais"], 2)
        self.assertEqual(self.stats["anglais_avec_audio"], 1)


class Rapport(unittest.TestCase):
    def test_fusion_et_rapport(self):
        _, p_en, s_en = a.analyse(lines("sample_en.jsonl"), "en")
        _, p_fr, _ = a.analyse(lines("sample_fr.jsonl"), "fr")
        cmp_ = r.compare(p_en, p_fr)
        self.assertEqual(cmp_["paires_communes"], 1)  # ("hello", "bonjour")
        self.assertEqual(cmp_["paires_union"], len(p_en | p_fr))
        # « cat » et « good morning » n'existent que dans l'édition française
        self.assertEqual(cmp_["mots_anglais_gagnes_par_fusion"], 2)

    def test_ecriture_complete(self):
        with tempfile.TemporaryDirectory() as d:
            for ed, name in (("en", "sample_en.jsonl"), ("fr", "sample_fr.jsonl")):
                s, p, smp = a.analyse(lines(name), ed)
                a.write_outputs(d, ed, s, p, smp)
            with contextlib.redirect_stdout(io.StringIO()):
                r.main(["--dir", d])
            with open(os.path.join(d, "rapport_phase0.md"), encoding="utf-8") as f:
                md = f.read()
            self.assertIn("Fusion des traductions", md)
            with open(os.path.join(d, "rapport_phase0.json"), encoding="utf-8") as f:
                data = json.load(f)
            self.assertEqual(data["fusion"]["paires_communes"], 1)
            with gzip.open(os.path.join(d, "en_pairs.tsv.gz"), "rt", encoding="utf-8") as f:
                self.assertEqual(len(f.read().splitlines()), 4)

    def test_taille_totale_depuis_les_en_tetes(self):
        self.assertEqual(r.parse_total({"Content-Range": "bytes 0-0/12345"}), 12345)
        self.assertEqual(r.parse_total({"Content-Length": "987"}), 987)
        self.assertIsNone(r.parse_total({"Content-Range": "bytes */*"}))
        self.assertIsNone(r.parse_total({}))

    def test_echappement_annotation(self):
        self.assertEqual(r.gh_escape("a%b\nc"), "a%25b%0Ac")


class Couverture(unittest.TestCase):
    def _dossier(self, d):
        for ed, name in (("en", "sample_en.jsonl"), ("fr", "sample_fr.jsonl")):
            with gzip.open(os.path.join(d, "%s_entries.tsv.gz" % ed), "wt", encoding="utf-8") as out:
                s, p, smp = a.analyse(lines(name), ed, entries_out=out)
            a.write_outputs(d, ed, s, p, smp)

    def test_ligne_d_entree_et_renvoi(self):
        senses = [{"glosses": ["simple past tense of go"], "form_of": [{"word": "go"}]}]
        ligne = a.entry_line("Went", "verb", senses, False, False)
        self.assertEqual(ligne, "went\tverb\t1\tgo\t0\t1\t0\n")
        self.assertEqual(a.form_lemma([{"glosses": ["x"]}]), (False, ""))

    def test_categories_et_pourcentages(self):
        with tempfile.TemporaryDirectory() as d:
            self._dossier(d)
            ctx = cf.Context(d)
            self.assertEqual(ctx.category("go"), "traduction")
            self.assertEqual(ctx.category("went"), "traduction")       # via le mot de base
            self.assertEqual(ctx.category("cat"), "traduction")        # apporté par l'édition française
            self.assertEqual(ctx.category("run"), "definition_fr")
            self.assertEqual(ctx.category("ephemeral"), "entree_seule")
            self.assertEqual(ctx.category("ran"), "absent")
            words = ["go", "went", "hello", "cat", "run", "ran", "ephemeral", "zzzz"]
            res = cf.evaluate(ctx, words)
            e = res["seuils"]["8"]
            self.assertEqual((e["traduction"], e["definition_fr"], e["entree_seule"], e["absent"]),
                             (4, 1, 1, 2))
            self.assertEqual(e["traduction_pct"], 50.0)
            self.assertEqual(e["traduction_edition_anglaise_seule"], 3)  # go, went, hello
            self.assertEqual(e["traduction_ou_definition_pct"], 62.5)
            self.assertIn("ephemeral (entree_seule)", res["exemples_sans_equivalent"])
            self.assertIn("## Mots très courants", cf.build_markdown(res))

    def test_nettoyage_de_la_liste(self):
        self.assertEqual(cf.clean_words(["The", "the", "don\u2019t", "3d", "e-mail", "ok"]),
                         ["the", "don't", "ok"])

    def test_cli_avec_liste_de_mots(self):
        with tempfile.TemporaryDirectory() as d:
            self._dossier(d)
            liste = os.path.join(d, "mots.txt")
            with open(liste, "w", encoding="utf-8") as f:
                f.write("go\nhello\nephemeral\n")
            with contextlib.redirect_stdout(io.StringIO()):
                cf.main(["--dir", d, "--wordlist", liste])
            with open(os.path.join(d, "couverture_frequence.json"), encoding="utf-8") as f:
                res = json.load(f)
            self.assertEqual(res["mots_dans_la_liste"], 3)


if __name__ == "__main__":
    unittest.main()
