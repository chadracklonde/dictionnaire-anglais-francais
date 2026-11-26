#!/usr/bin/env python3
"""Captures d'écran réelles de l'application dans un émulateur Android (appelé par build.yml).

  python3 tools/captures_android.py app-release.apk dossier_sortie

L'application est installée puis pilotée avec `adb` : les éléments sont retrouvés par leur texte
(`uiautomator dump`, Flutter expose ses libellés). Chaque étape est tentée ; une étape qui échoue
laisse son dump d'écran dans `dossier_sortie/echec_<étape>.xml` et le scénario continue, pour
qu'une capture manquante n'empêche pas les autres.
"""
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PAQUET = "com.chadracklonde.dicoenfr"
SORTIE = "."


def adb(*args, timeout=120, binaire=False):
    r = subprocess.run(["adb", *args], capture_output=True, timeout=timeout)
    return r.stdout if binaire else r.stdout.decode("utf-8", "replace")


def noeuds():
    """Éléments de l'écran : liste de dicts (texte, classe, cliquable, rectangle)."""
    for _ in range(6):
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        brut = adb("exec-out", "cat", "/sdcard/ui.xml")
        if "<hierarchy" in brut:
            break
        time.sleep(1.5)
    else:
        return []
    try:
        racine = ET.fromstring(brut[brut.index("<hierarchy"):])
    except ET.ParseError:
        return []
    liste = []
    for n in racine.iter("node"):
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
        if not m:
            continue
        x1, y1, x2, y2 = map(int, m.groups())
        texte = " ".join(filter(None, [n.get("text", ""), n.get("content-desc", "")]))
        liste.append({"texte": texte, "classe": n.get("class", ""), "clic": n.get("clickable") == "true",
                      "r": (x1, y1, x2, y2)})
    return liste


def premier_mot(texte):
    return texte.split("\n")[0].strip()


def trouver(liste, contient=None, exact=None, classe=None, clic=None):
    for n in liste:
        t = n["texte"].casefold()
        if contient and contient.casefold() not in t:
            continue
        if exact and premier_mot(n["texte"]).casefold() != exact.casefold():
            continue
        if classe and classe not in n["classe"]:
            continue
        if clic is not None and n["clic"] != clic:
            continue
        return n
    return None


def attendre(timeout=60, **criteres):
    fin = time.time() + timeout
    while time.time() < fin:
        n = trouver(noeuds(), **criteres)
        if n:
            return n
        time.sleep(1.5)
    raise RuntimeError("introuvable : %r" % (criteres,))


def toucher(n):
    x1, y1, x2, y2 = n["r"]
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
    time.sleep(1.2)


def saisir(texte):
    adb("shell", "input", "text", texte.replace(" ", "%s"))
    time.sleep(0.8)


def touche(code):
    adb("shell", "input", "keyevent", str(code))
    time.sleep(1.0)


def capturer(nom):
    time.sleep(1.5)
    png = adb("exec-out", "screencap", "-p", binaire=True)
    with open(os.path.join(SORTIE, nom + ".png"), "wb") as f:
        f.write(png)
    print("capture", nom, len(png) // 1024, "Ko", flush=True)


def etape(nom, fonction):
    try:
        fonction()
        print("ok", nom, flush=True)
        return True
    except Exception as e:  # noqa: BLE001 - on garde la trace et on continue
        print("ECHEC", nom, e, flush=True)
        try:
            with open(os.path.join(SORTIE, "echec_%s.txt" % nom), "w", encoding="utf-8") as f:
                f.write(str(e) + "\n\n")
                for n in noeuds():
                    f.write("%s | %s | clic=%s | %s\n" % (n["texte"].replace("\n", " / "), n["classe"], n["clic"], n["r"]))
            capturer("echec_" + nom)
        except Exception:  # noqa: BLE001
            pass
        return False


def chercher_mot(mot):
    """Depuis l'accueil : saisit le mot et lance la recherche."""
    revenir_accueil()
    ancien = trouver(noeuds(), exact="Effacer")
    if ancien:
        toucher(ancien)
    champ = attendre(30, classe="EditText")
    toucher(champ)
    saisir(mot)
    touche(66)  # Entrée


def defiler(bas=True):
    """Fait défiler la liste d'un écran de téléphone (ou de tablette)."""
    taille = adb("shell", "wm", "size")
    m = re.search(r"(\d+)x(\d+)", taille.split("Override")[-1] if "Override" in taille else taille)
    largeur, hauteur = (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)
    x = largeur // 2
    y1, y2 = (int(hauteur * 0.75), int(hauteur * 0.30)) if bas else (int(hauteur * 0.30), int(hauteur * 0.75))
    adb("shell", "input", "swipe", str(x), str(y1), str(x), str(y2), "350")
    time.sleep(1.0)


def attendre_defilant(essais=6, **criteres):
    """Cherche un élément en faisant défiler vers le bas jusqu'à ce qu'il apparaisse."""
    for _ in range(essais):
        n = trouver(noeuds(), **criteres)
        if n:
            return n
        defiler()
    raise RuntimeError("introuvable après défilement : %r" % (criteres,))


def revenir_accueil():
    """Remonte jusqu'à l'accueil (après une étape ratée on peut être resté sur un autre écran)."""
    for _ in range(5):
        liste = noeuds()
        if trouver(liste, contient="Mot du jour") or trouver(liste, contient="Rechercher un mot"):
            return
        touche(4)


def retour():
    touche(4)
    time.sleep(1.0)


def favori():
    n = trouver(noeuds(), contient="Ajouter aux favoris")
    if n:
        toucher(n)


def main_court(apk, sortie):
    """Scénario réduit pour les grands écrans (tablette, appareil pliable) : quelques captures utiles."""
    global SORTIE
    SORTIE = sortie
    os.makedirs(sortie, exist_ok=True)
    adb("install", "-r", apk, timeout=600)
    adb("shell", "settings", "put", "global", "window_animation_scale", "0")
    adb("shell", "monkey", "-p", PAQUET, "-c", "android.intent.category.LAUNCHER", "1")
    fin = time.time() + 420
    while time.time() < fin:
        liste = noeuds()
        if trouver(liste, contient="Mot du jour"):
            break
        passer = trouver(liste, exact="Passer")
        if passer:
            toucher(passer)
            continue
        time.sleep(3)
    else:
        print("ECHEC l'accueil n'est jamais apparu", flush=True)
        return 1
    etape("accueil", lambda: capturer("t01_accueil"))

    def fiche():
        chercher_mot("borrow")
        attendre(60, contient="Exemples")
        capturer("t02_fiche")
        retour()
    etape("fiche", fiche)

    def expressions():
        revenir_accueil()
        toucher(attendre_defilant(exact="Expressions", clic=True))
        attendre(30, classe="EditText")
        capturer("t03_expressions")
        retour()
    etape("expressions", expressions)

    def reviser():
        revenir_accueil()
        toucher(attendre(30, exact="Réviser"))
        attendre(30, contient="Quels mots")
        capturer("t04_reviser")
    etape("reviser", reviser)
    return 0


def main(apk, sortie):
    global SORTIE
    SORTIE = sortie
    os.makedirs(sortie, exist_ok=True)
    adb("install", "-r", apk, timeout=600)
    adb("shell", "settings", "put", "global", "window_animation_scale", "0")
    adb("shell", "monkey", "-p", PAQUET, "-c", "android.intent.category.LAUNCHER", "1")

    def demarrage():
        # La base est recopiée au premier lancement : jusqu'à quelques minutes.
        fin = time.time() + 420
        while time.time() < fin:
            liste = noeuds()
            if trouver(liste, contient="Rechercher un mot", classe="EditText") or trouver(liste, contient="Mot du jour"):
                return
            passer = trouver(liste, exact="Passer")
            if passer:
                toucher(passer)
                continue
            time.sleep(3)
        raise RuntimeError("l'accueil n'est jamais apparu")
    if not etape("demarrage", demarrage):
        return 1

    def accueil():
        attendre(60, contient="Mot du jour")
        capturer("01_accueil")
    etape("accueil", accueil)

    def faux_ami():
        chercher_mot("actually")
        attendre(60, contient="Faux ami")
        capturer("02_faux_ami")
        favori()
        retour()
    etape("faux_ami", faux_ami)

    def fiche():
        chercher_mot("borrow")
        attendre(60, contient="Exemples")
        capturer("03_fiche")
        favori()
        retour()
    etape("fiche", fiche)

    def fiche_2():
        chercher_mot("journey")
        attendre(60, contient="journey")
        favori()
        retour()
    etape("fiche_2", fiche_2)

    def reviser():
        toucher(attendre(30, exact="Réviser"))
        attendre(30, contient="Quels mots")
        # une petite séance pour que l'objectif du jour et la série s'affichent
        toucher(attendre(30, contient="Réviser ("))
        for _ in range(2):
            toucher(attendre(60, contient="Voir la réponse"))
            if _ == 0:
                capturer("04_carte")
            toucher(attendre(30, contient="Je savais"))
        retour()
        attendre(30, contient="Quels mots")
        capturer("05_reviser")
    etape("reviser", reviser)

    def quiz():
        toucher(attendre(30, contient="Quiz : anglais"))
        attendre(90, contient="Question 1")
        liste = noeuds()
        options = [n for n in liste if n["clic"] and n["r"][2] - n["r"][0] > 700 and 120 < n["r"][3] - n["r"][1] < 260
                   and n["r"][1] > 500]
        if not options:
            raise RuntimeError("aucune réponse à toucher")
        toucher(options[0])
        capturer("06_quiz")
        retour()
    etape("quiz", quiz)

    def expressions():
        revenir_accueil()
        toucher(attendre(30, exact="Accueil"))
        toucher(attendre_defilant(exact="Expressions", clic=True))
        attendre(30, classe="EditText")
        capturer("08_expressions")
        toucher(attendre(30, contient="Phrases utiles"))
        time.sleep(2)
        capturer("09_phrases_utiles")
        retour()
    etape("expressions", expressions)

    def expression_fiche():
        chercher_mot("kick the bucket")
        attendre(60, contient="Équivalent recommandé")
        capturer("10_expression")
        retour()
    etape("expression_fiche", expression_fiche)

    def expression_mot():
        chercher_mot("bucket")
        attendre(60, contient="bucket")
        for _ in range(4):
            if trouver(noeuds(), contient="Expressions avec"):
                break
            defiler()
        capturer("11_expressions_avec")
        retour()
    etape("expression_mot", expression_mot)

    def trous():
        revenir_accueil()
        toucher(attendre(30, exact="Réviser"))
        toucher(attendre_defilant(contient="Phrases à trous"))
        attendre(90, contient="Complétez")
        capturer("12_trous")
        retour()
    etape("trous", trous)

    def reglages():
        revenir_accueil()
        toucher(attendre(30, exact="Accueil"))
        toucher(attendre(30, contient="Réglages"))
        attendre_defilant(contient="Rappel quotidien")
        defiler()
        capturer("13_reglages_rappel")
        retour()
    etape("reglages", reglages)

    def sombre():
        adb("shell", "cmd", "uimode", "night", "yes")
        time.sleep(3)
        toucher(attendre(30, exact="Accueil"))
        chercher_mot("actually")
        attendre(60, contient="Faux ami")
        capturer("07_sombre")
    etape("sombre", sombre)
    return 0


if __name__ == "__main__":
    court = len(sys.argv) > 3 and sys.argv[3] == "court"
    sys.exit((main_court if court else main)(sys.argv[1], sys.argv[2]))
