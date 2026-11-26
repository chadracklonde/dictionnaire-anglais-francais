#!/usr/bin/env python3
"""Ajoute le rappel quotidien de révision au projet Android généré par `flutter create`.

  python3 tools/android_rappel.py --android app/android

Copie le code Kotlin (tools/android/RappelPlugin.kt), une petite icône de notification, déclare les
permissions (notifications, redémarrage) et les récepteurs dans le manifeste, puis réécrit
MainActivity pour brancher le rappel (et les packs audio s'ils sont déjà installés).
Aucun greffon Flutter, aucune connexion : une alarme locale et une notification.
"""
import argparse
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
MARQUE = "<!-- rappel -->"

ICONE = """<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M4,5v13c1.5,-1 3.5,-1.5 8,-1.5s6.5,0.5 8,1.5V5c-1.5,-1 -3.5,-1.5 -8,-1.5S5.5,4 4,5z"/>
</vector>
"""


def _lire(chemin):
    with open(chemin, encoding="utf-8") as f:
        return f.read()


def _ecrire(chemin, texte):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(texte)


def trouver_activite(android):
    racine = os.path.join(android, "app", "src", "main", "kotlin")
    for dossier, _, fichiers in os.walk(racine):
        if "MainActivity.kt" in fichiers:
            return os.path.join(dossier, "MainActivity.kt")
    raise FileNotFoundError("MainActivity.kt sous " + racine)


def patcher_manifeste(android, paquet):
    chemin = os.path.join(android, "app", "src", "main", "AndroidManifest.xml")
    texte = _lire(chemin)
    if MARQUE in texte:
        return
    permissions = (MARQUE + '\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
                   '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n    ')
    texte, n = re.subn(r"<application", lambda m: permissions + "<application", texte, count=1)
    if n != 1:
        raise RuntimeError("balise <application> introuvable dans " + chemin)
    recepteurs = (
        '    <receiver android:name="%s.RappelReceiver" android:exported="false"/>\n'
        '    <receiver android:name="%s.RappelBootReceiver" android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '        </intent-filter>\n'
        '    </receiver>\n' % (paquet, paquet))
    texte, n = re.subn(r"</application>", lambda m: recepteurs + "    </application>", texte, count=1)
    if n != 1:
        raise RuntimeError("balise </application> introuvable dans " + chemin)
    _ecrire(chemin, texte)


def ecrire_activite(activite, paquet, avec_audio):
    audio = "        AudioPacksPlugin(this, flutterEngine)\n" if avec_audio else ""
    _ecrire(activite,
            "package %s\n\nimport io.flutter.embedding.android.FlutterActivity\n"
            "import io.flutter.embedding.engine.FlutterEngine\n\n"
            "class MainActivity : FlutterActivity() {\n"
            "    private var rappel: RappelPlugin? = null\n\n"
            "    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {\n"
            "        super.configureFlutterEngine(flutterEngine)\n"
            "%s"
            "        rappel = RappelPlugin(this, flutterEngine)\n    }\n\n"
            "    override fun onRequestPermissionsResult(\n"
            "        requestCode: Int, permissions: Array<String>, grantResults: IntArray\n    ) {\n"
            "        super.onRequestPermissionsResult(requestCode, permissions, grantResults)\n"
            "        rappel?.surPermission(requestCode, grantResults)\n    }\n}\n" % (paquet, audio))


def installer(android):
    activite = trouver_activite(android)
    dossier = os.path.dirname(activite)
    paquet = re.search(r"^package\s+([\w.]+)", _lire(activite), re.M).group(1)
    avec_audio = os.path.exists(os.path.join(dossier, "AudioPacksPlugin.kt"))
    plugin = _lire(os.path.join(HERE, "android", "RappelPlugin.kt"))
    plugin = re.sub(r"^package\s+[\w.]+", "package " + paquet, plugin, count=1, flags=re.M)
    _ecrire(os.path.join(dossier, "RappelPlugin.kt"), plugin)
    _ecrire(os.path.join(android, "app", "src", "main", "res", "drawable", "ic_rappel.xml"), ICONE)
    patcher_manifeste(android, paquet)
    ecrire_activite(activite, paquet, avec_audio)
    return paquet, avec_audio


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--android", required=True)
    args = p.parse_args(argv)
    paquet, audio = installer(args.android)
    print("Rappel quotidien branché (paquet %s, audio %s)" % (paquet, "oui" if audio else "non"))


if __name__ == "__main__":
    main()
