"""Contrastes WCAG AA (4,5:1) des couleurs de app/lib/theme.dart."""
import re
import unittest
from pathlib import Path

THEME = Path(__file__).resolve().parent.parent / "app" / "lib" / "theme.dart"


def couleurs():
    return {m.group(1): m.group(2).upper()
            for m in re.finditer(r"static const Color (\w+) = Color\(0xFF([0-9A-Fa-f]{6})\);",
                                 THEME.read_text(encoding="utf-8"))}


def luminance(hexa):
    canaux = []
    for i in (0, 2, 4):
        c = int(hexa[i:i + 2], 16) / 255
        canaux.append(c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * canaux[0] + 0.7152 * canaux[1] + 0.0722 * canaux[2]


def contraste(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


PAIRES = [
    # (texte, fond)
    ("clairSurPrimaire", "clairPrimaire"),
    ("clairSurSecondaire", "clairSecondaire"),
    ("clairPrimaire", "clairSurface"),
    ("clairSecondaire", "clairSurface"),
    ("clairTertiaire", "clairSurface"),
    ("clairTexte", "clairSurface"),
    ("clairTexteDiscret", "clairSurface"),
    ("sombreSurPrimaire", "sombrePrimaire"),
    ("sombreSurSecondaire", "sombreSecondaire"),
    ("sombrePrimaire", "sombreSurface"),
    ("sombreSecondaire", "sombreSurface"),
    ("sombreTertiaire", "sombreSurface"),
    ("sombreTexte", "sombreSurface"),
    ("sombreTexteDiscret", "sombreSurface"),
]


class TestContrastes(unittest.TestCase):
    def test_paires(self):
        c = couleurs()
        for texte, fond in PAIRES:
            self.assertIn(texte, c)
            self.assertIn(fond, c)
            ratio = contraste(c[texte], c[fond])
            self.assertGreaterEqual(ratio, 4.5, "%s sur %s : %.2f" % (texte, fond, ratio))


if __name__ == "__main__":
    unittest.main()
