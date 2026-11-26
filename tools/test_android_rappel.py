"""Test du branchement du rappel quotidien sur un projet Android factice."""
import os
import tempfile
import unittest

import android_rappel as r

MANIFESTE = ('<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
             '    <application android:label="x">\n        <activity android:name=".MainActivity"/>\n'
             '    </application>\n</manifest>\n')


def projet(avec_audio=False):
    android = os.path.join(tempfile.mkdtemp(), "android")
    kotlin = os.path.join(android, "app", "src", "main", "kotlin", "com", "chadracklonde", "dicoenfr")
    os.makedirs(kotlin)
    with open(os.path.join(kotlin, "MainActivity.kt"), "w") as f:
        f.write("package com.chadracklonde.dicoenfr\n\nclass MainActivity : FlutterActivity()\n")
    if avec_audio:
        open(os.path.join(kotlin, "AudioPacksPlugin.kt"), "w").close()
    with open(os.path.join(android, "app", "src", "main", "AndroidManifest.xml"), "w") as f:
        f.write(MANIFESTE)
    return android, kotlin


class AndroidRappel(unittest.TestCase):
    def test_installation(self):
        android, kotlin = projet()
        paquet, audio = r.installer(android)
        self.assertEqual((paquet, audio), ("com.chadracklonde.dicoenfr", False))
        manifeste = open(os.path.join(android, "app", "src", "main", "AndroidManifest.xml")).read()
        self.assertIn("POST_NOTIFICATIONS", manifeste)
        self.assertIn("RECEIVE_BOOT_COMPLETED", manifeste)
        self.assertIn('android:name="com.chadracklonde.dicoenfr.RappelReceiver"', manifeste)
        self.assertIn("MY_PACKAGE_REPLACED", manifeste)
        self.assertLess(manifeste.index("RappelReceiver"), manifeste.index("</application>"))
        self.assertLess(manifeste.index("POST_NOTIFICATIONS"), manifeste.index("<application"))
        activite = open(os.path.join(kotlin, "MainActivity.kt")).read()
        self.assertIn("RappelPlugin(this, flutterEngine)", activite)
        self.assertIn("onRequestPermissionsResult", activite)
        self.assertNotIn("AudioPacksPlugin", activite)
        plugin = open(os.path.join(kotlin, "RappelPlugin.kt")).read()
        self.assertTrue(plugin.startswith("package com.chadracklonde.dicoenfr"))
        self.assertTrue(os.path.exists(os.path.join(android, "app", "src", "main", "res", "drawable", "ic_rappel.xml")))

    def test_avec_audio_et_deux_fois(self):
        android, kotlin = projet(True)
        r.installer(android)
        r.installer(android)  # relancé : le manifeste n'est pas dupliqué
        activite = open(os.path.join(kotlin, "MainActivity.kt")).read()
        self.assertIn("AudioPacksPlugin(this, flutterEngine)", activite)
        manifeste = open(os.path.join(android, "app", "src", "main", "AndroidManifest.xml")).read()
        self.assertEqual(manifeste.count("RappelReceiver"), 1)

    def test_kotlin_equilibre(self):
        texte = open(os.path.join(r.HERE, "android", "RappelPlugin.kt"), encoding="utf-8").read()
        for ouvrant, fermant in ("{}", "()"):
            self.assertEqual(texte.count(ouvrant), texte.count(fermant), ouvrant)


if __name__ == "__main__":
    unittest.main()
