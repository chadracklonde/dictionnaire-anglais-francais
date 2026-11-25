"""Test du branchement des packs audio sur un projet Android factice."""
import os
import tempfile
import unittest
import zipfile

import android_audio as a


def projet(kts=True):
    racine = tempfile.mkdtemp()
    android = os.path.join(racine, "android")
    os.makedirs(os.path.join(android, "app", "src", "main", "kotlin", "com", "chadracklonde", "dicoenfr"))
    ext = ".kts" if kts else ""
    with open(os.path.join(android, "settings.gradle" + ext), "w") as f:
        f.write('include(":app")\n' if kts else "include ':app'\n")
    with open(os.path.join(android, "app", "build.gradle" + ext), "w") as f:
        f.write('plugins { id("com.android.application") }\n\nandroid {\n    namespace = "x"\n}\n\nflutter {\n    source = "../.."\n}\n'
                if kts else "plugins { id 'com.android.application' }\n\nandroid {\n    namespace 'x'\n}\n")
    with open(os.path.join(android, "app", "src", "main", "kotlin", "com", "chadracklonde", "dicoenfr",
                           "MainActivity.kt"), "w") as f:
        f.write("package com.chadracklonde.dicoenfr\n\nimport io.flutter.embedding.android.FlutterActivity\n\n"
                "class MainActivity : FlutterActivity()\n")
    zips = os.path.join(racine, "zips")
    os.makedirs(zips)
    for pack, fichiers in (("audio_us_core", ["a.ogg", "b.ogg"]), ("audio_us_1", ["c.ogg"])):
        with zipfile.ZipFile(os.path.join(zips, pack + ".zip"), "w") as z:
            for f in fichiers:
                z.writestr(f, b"ogg")
            z.writestr("../evil.txt", b"x")  # chemin piégé : doit être ramené à un nom simple
    return android, zips


class AndroidAudio(unittest.TestCase):
    def test_kotlin_dsl(self):
        android, zips = projet(True)
        nb = a.installer(android, zips)
        self.assertEqual(nb, {"audio_us_1": 2, "audio_us_core": 3})  # evil.txt devient un fichier simple
        core = open(os.path.join(android, "audio_us_core", "build.gradle.kts")).read()
        self.assertIn('packName.set("audio_us_core")', core)
        self.assertIn('deliveryType.set("install-time")', core)
        self.assertIn('deliveryType.set("on-demand")', open(os.path.join(android, "audio_us_1", "build.gradle.kts")).read())
        self.assertTrue(os.path.exists(os.path.join(android, "audio_us_core", "src", "main", "assets", "audio", "a.ogg")))
        self.assertFalse(os.path.exists(os.path.join(android, "evil.txt")))
        settings = open(os.path.join(android, "settings.gradle.kts")).read()
        self.assertIn('include(":audio_us_core")', settings)
        self.assertIn('include(":audio_us_1")', settings)
        app = open(os.path.join(android, "app", "build.gradle.kts")).read()
        self.assertIn('assetPacks.addAll(listOf(":audio_us_1", ":audio_us_core"))', app)
        self.assertIn("com.google.android.play:asset-delivery:", app)
        self.assertLess(app.index("assetPacks"), app.index("flutter {"))
        activite = os.path.join(android, "app", "src", "main", "kotlin", "com", "chadracklonde", "dicoenfr")
        self.assertIn("AudioPacksPlugin(this, flutterEngine)", open(os.path.join(activite, "MainActivity.kt")).read())
        self.assertIn("package com.chadracklonde.dicoenfr", open(os.path.join(activite, "AudioPacksPlugin.kt")).read())

    def test_deux_fois_de_suite_sans_doublon(self):
        android, zips = projet(True)
        a.installer(android, zips)
        a.installer(android, zips)
        app = open(os.path.join(android, "app", "build.gradle.kts")).read()
        self.assertEqual(app.count("assetPacks.addAll"), 1)
        self.assertEqual(open(os.path.join(android, "settings.gradle.kts")).read().count('include(":audio_us_core")'), 1)

    def test_groovy(self):
        android, zips = projet(False)
        a.installer(android, zips)
        app = open(os.path.join(android, "app", "build.gradle")).read()
        self.assertIn("assetPacks = [':audio_us_1', ':audio_us_core']", app)
        self.assertIn("include ':audio_us_core'", open(os.path.join(android, "settings.gradle")).read())
        self.assertTrue(os.path.exists(os.path.join(android, "audio_us_core", "build.gradle")))


if __name__ == "__main__":
    unittest.main()
