#!/usr/bin/env python3
"""Génère l'icône de l'application : un livre ouvert, « EN » sur la page de gauche et « FR » sur celle de droite.

    python3 tools/make_icon.py [--preview aperçu.png]

Écrit app/assets/icon/{logo,logo_full,logo_foreground,logo_background}.png (1024 px).
Nécessite Pillow et la police Poppins Bold (chemin ci-dessous, à adapter).
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "app" / "assets" / "icon"
FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
S = 2048  # dessin en double résolution, réduit à 1024
BLEU, ROUGE, OR, CREME = (28, 72, 111), (165, 14, 26), (242, 182, 50), (255, 248, 231)
FOND_HAUT, FOND_BAS = (176, 18, 30), (74, 0, 16)


def fond():
    img = Image.new("RGB", (S, S))
    px = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        px.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(FOND_HAUT, FOND_BAS)))
    return img.convert("RGBA")


def livre(largeur):
    """Calque transparent S×S avec le livre centré, large de `largeur` px (en 2048)."""
    calque = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    cx, cy = S // 2, S // 2
    bw = largeur
    bh = int(bw * 0.78)
    x0, y0 = cx - bw // 2, cy - bh // 2
    r = int(bw * 0.06)
    # ombre portée
    ombre = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).rounded_rectangle([x0, y0 + bw * 0.03, x0 + bw, y0 + bh + bw * 0.03], r, fill=(0, 0, 0, 90))
    calque.alpha_composite(ombre)
    d = ImageDraw.Draw(calque)
    # couverture dorée
    d.rounded_rectangle([x0, y0, x0 + bw, y0 + bh], r, fill=OR)
    # tranche des pages (bas)
    marge = int(bw * 0.04)
    px0, px1 = x0 + marge, x0 + bw - marge
    py0, py1 = y0 + marge, y0 + bh - marge * 2.2
    gap = int(bw * 0.012)
    for k, teinte in enumerate([(214, 200, 168), (232, 220, 190)]):
        d.rounded_rectangle([px0, py1 - marge * 0.2 + k * marge * 0.9, px1, py1 + marge * (0.9 + k * 0.9)],
                            int(r * 0.5), fill=teinte)
    # pages
    pr = int(bw * 0.04)
    d.rounded_rectangle([px0, py0, cx - gap, py1 + marge * 0.3], pr, fill=CREME)
    d.rounded_rectangle([cx + gap, py0, px1, py1 + marge * 0.3], pr, fill=CREME)
    # reliure
    d.rectangle([cx - gap, py0 + pr, cx + gap, py1 - pr], fill=(222, 206, 170))
    # lettres : même corps pour les deux, aussi grand que la page le permet
    largeur_page = (px1 - px0) / 2 - gap
    taille = 100
    while True:
        f = ImageFont.truetype(FONT, taille + 4)
        if max(f.getlength("EN"), f.getlength("FR")) > largeur_page * 0.84:
            break
        taille += 4
    f = ImageFont.truetype(FONT, taille)
    for texte, couleur, centre in (("EN", BLEU, (px0 + cx - gap) / 2), ("FR", ROUGE, (cx + gap + px1) / 2)):
        box = d.textbbox((0, 0), texte, font=f)
        w, h = box[2] - box[0], box[3] - box[1]
        d.text((centre - w / 2 - box[0], (py0 + py1 + marge * 0.3) / 2 - h / 2 - box[1]), texte, font=f, fill=couleur)
    return calque


def reduire(img):
    return img.resize((1024, 1024), Image.LANCZOS)


def coins_arrondis(img, rayon):
    masque = Image.new("L", img.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], rayon, fill=255)
    out = img.copy()
    out.putalpha(masque)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    # Icône pleine (Android ancien, aperçu) : livre très grand
    plein = fond()
    plein.alpha_composite(livre(int(S * 0.76)))
    reduire(plein).convert("RGB").save(OUT / "logo_full.png")
    reduire(coins_arrondis(plein, int(S * 0.22))).save(OUT / "logo.png")
    reduire(coins_arrondis(plein, int(S * 0.22))).save(OUT / "book.png")  # écran de démarrage
    # Adaptatif : le livre reste dans la zone sûre (66 % du côté)
    reduire(livre(int(S * 0.66))).save(OUT / "logo_foreground.png")
    reduire(fond()).convert("RGB").save(OUT / "logo_background.png")
    if args.preview:
        # aperçu : rond (Android), carré arrondi, et petite taille
        prev = Image.new("RGB", (1500, 520), (240, 240, 240))
        base = reduire(plein)
        rond = Image.new("L", (1024, 1024), 0)
        ImageDraw.Draw(rond).ellipse([0, 0, 1023, 1023], fill=255)
        a = base.copy(); a.putalpha(rond)
        prev.paste(a.resize((440, 440), Image.LANCZOS), (40, 40), a.resize((440, 440), Image.LANCZOS))
        b = reduire(coins_arrondis(plein, int(S * 0.22)))
        prev.paste(b.resize((440, 440), Image.LANCZOS), (540, 40), b.resize((440, 440), Image.LANCZOS))
        c = b.resize((96, 96), Image.LANCZOS)
        prev.paste(c, (1060, 40), c)
        c2 = b.resize((48, 48), Image.LANCZOS)
        prev.paste(c2, (1060, 180), c2)
        prev.save(args.preview)


if __name__ == "__main__":
    main()
