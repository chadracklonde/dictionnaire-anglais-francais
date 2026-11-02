"""Tests de la phase 0 : python3 -m unittest discover -s tools -p "test_*.py"."""
import contextlib
import gzip
import io
import json
import os
import tempfile
import unittest

import analyse_wiktionnaire as a
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

    def test_echappement_annotation(self):
        self.assertEqual(r.gh_escape("a%b\nc"), "a%25b%0Ac")


if __name__ == "__main__":
    unittest.main()
