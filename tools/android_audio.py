#!/usr/bin/env python3
"""Ajoute les packs audio (Play Asset Delivery) au projet Android généré par `flutter create`.

  python3 tools/android_audio.py --android app/android --zips audio_zips

Pour chaque `audio_us_*.zip` : un module Gradle `asset-pack` (livraison à l'installation pour
`audio_us_core`, à la demande pour les autres), déclaré dans settings.gradle(.kts) et
app/build.gradle(.kts). Ajoute aussi la bibliothèque Play Asset Delivery, le code Kotlin qui
gère les packs et lit les enregistrements, et le branche dans MainActivity.
"""
import argparse
import os
import re
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION_ASSET_DELIVERY = "2.2.2"
MARQUE = "// dicoenfr-audio"


def _lire(chemin):
    with open(chemin, encoding="utf-8") as f:
        return f.read()


def _ecrire(chemin, texte):
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(texte)


def _existant(*chemins):
    for c in chemins:
        if os.path.exists(c):
            return c
    raise FileNotFoundError(" ou ".join(chemins))


def livraison(pack):
    """Cœur livré avec l'application ; les autres packs se téléchargent à la demande."""
    return "install-time" if pack.endswith("_core") else "on-demand"


def creer_module(android, pack, zip_chemin, kotlin):
    """Crée android/<pack> : build.gradle(.kts) et les fichiers dans src/main/assets/audio."""
    dossier = os.path.join(android, pack)
    assets = os.path.join(dossier, "src", "main", "assets", "audio")
    os.makedirs(assets, exist_ok=True)
    with zipfile.ZipFile(zip_chemin) as z:
        for nom in z.namelist():
            # un nom de fichier seul : jamais de chemin venu de l'archive
            base = os.path.basename(nom)
            if base and not nom.endswith("/"):
                with z.open(nom) as src, open(os.path.join(assets, base), "wb") as dst:
                    shutil.copyfileobj(src, dst)
    if kotlin:
        _ecrire(os.path.join(dossier, "build.gradle.kts"),
                'plugins { id("com.android.asset-pack") }\n\nassetPack {\n'
                '    packName.set("%s")\n    dynamicDelivery { deliveryType.set("%s") }\n}\n'
                % (pack, livraison(pack)))
    else:
        _ecrire(os.path.join(dossier, "build.gradle"),
                "plugins { id 'com.android.asset-pack' }\n\nassetPack {\n"
                "    packName = \"%s\"\n    dynamicDelivery { deliveryType = \"%s\" }\n}\n"
                % (pack, livraison(pack)))
    return len(os.listdir(assets))


def patcher_settings(android, packs):
    chemin = _existant(os.path.join(android, "settings.gradle.kts"), os.path.join(android, "settings.gradle"))
    kts = chemin.endswith(".kts")
    texte = _lire(chemin)
    if MARQUE in texte:
        return kts
    lignes = "\n".join(('include(":%s")' if kts else "include ':%s'") % p for p in packs)
    _ecrire(chemin, texte.rstrip() + "\n\n" + MARQUE + "\n" + lignes + "\n")
    return kts


def patcher_app(android, packs, kts):
    chemin = _existant(os.path.join(android, "app", "build.gradle.kts"),
                       os.path.join(android, "app", "build.gradle"))
    texte = _lire(chemin)
    if MARQUE in texte:
        return
    liste = ", ".join('":%s"' % p for p in packs)
    if kts:
        bloc_packs = "    %s\n    assetPacks.addAll(listOf(%s))\n" % (MARQUE, liste)
        dep = 'dependencies {\n    implementation("com.google.android.play:asset-delivery:%s")\n}\n' % VERSION_ASSET_DELIVERY
    else:
        bloc_packs = "    %s\n    assetPacks = [%s]\n" % (MARQUE, liste.replace('"', "'"))
        dep = "dependencies {\n    implementation 'com.google.android.play:asset-delivery:%s'\n}\n" % VERSION_ASSET_DELIVERY
    nouveau, n = re.subn(r"(^android\s*\{\n)", lambda m: m.group(1) + bloc_packs, texte, count=1, flags=re.M)
    if n != 1:
        raise RuntimeError("bloc « android { » introuvable dans " + chemin)
    _ecrire(chemin, nouveau.rstrip() + "\n\n" + dep)


def brancher_kotlin(android):
    """Copie le plugin et remplace MainActivity par une version qui l'enregistre."""
    racine = os.path.join(android, "app", "src", "main", "kotlin")
    activite = None
    for dossier, _, fichiers in os.walk(racine):
        if "MainActivity.kt" in fichiers:
            activite = os.path.join(dossier, "MainActivity.kt")
    if activite is None:
        raise FileNotFoundError("MainActivity.kt sous " + racine)
    paquet = re.search(r"^package\s+([\w.]+)", _lire(activite), re.M).group(1)
    plugin = _lire(os.path.join(HERE, "android", "AudioPacksPlugin.kt"))
    plugin = re.sub(r"^package\s+[\w.]+", "package " + paquet, plugin, count=1, flags=re.M)
    _ecrire(os.path.join(os.path.dirname(activite), "AudioPacksPlugin.kt"), plugin)
    _ecrire(activite,
            "package %s\n\nimport io.flutter.embedding.android.FlutterActivity\n"
            "import io.flutter.embedding.engine.FlutterEngine\n\n"
            "class MainActivity : FlutterActivity() {\n"
            "    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {\n"
            "        super.configureFlutterEngine(flutterEngine)\n"
            "        AudioPacksPlugin(this, flutterEngine)\n    }\n}\n" % paquet)
    return paquet


def installer(android, zips):
    packs = sorted(f[:-4] for f in os.listdir(zips) if f.startswith("audio_us_") and f.endswith(".zip"))
    if not packs:
        raise RuntimeError("aucun audio_us_*.zip dans " + zips)
    kts = os.path.exists(os.path.join(android, "settings.gradle.kts"))
    nb = {p: creer_module(android, p, os.path.join(zips, p + ".zip"), kts) for p in packs}
    patcher_settings(android, packs)
    patcher_app(android, packs, kts)
    brancher_kotlin(android)
    return nb


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--android", required=True)
    p.add_argument("--zips", required=True)
    args = p.parse_args(argv)
    for pack, n in installer(args.android, args.zips).items():
        print("%s : %d fichiers (%s)" % (pack, n, livraison(pack)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
