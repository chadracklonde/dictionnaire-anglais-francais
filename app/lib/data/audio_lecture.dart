import 'package:dicoenfr_engine/dicoenfr_engine.dart';

import 'audio_index.dart';
import 'audio_packs.dart';

/// Lecture d'un enregistrement du Wiktionnaire (accent américain), s'il est installé.
class LectureAudio {
  LectureAudio._();

  /// Joue l'enregistrement de la fiche et renvoie son crédit ; renvoie null s'il n'y en a pas
  /// (pas d'enregistrement, pack non téléchargé, appareil sans Google Play) : l'appelant utilise
  /// alors la synthèse vocale.
  static Future<EntreeAudio?> lire(Fiche fiche) async {
    if (!AudioPacks.disponible) return null;
    final index = await IndexAudio.obtenir();
    if (index.vide) return null;
    for (final a in fiche.audio) {
      if (a.accent != 'us') continue;
      final entree = index.entree(a.fichier);
      if (entree == null) continue;
      final chemin = await AudioPacks.chemin(entree.pack, entree.fichier);
      if (chemin == null) continue;
      if (await AudioPacks.jouer(chemin)) return entree;
    }
    return null;
  }
}
