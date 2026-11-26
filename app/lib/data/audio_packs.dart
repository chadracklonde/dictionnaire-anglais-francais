import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// État d'un pack d'enregistrements. [statut] vaut : pret, absent, attente, wifi, telechargement,
/// transfert, confirmation, echec, annule, indisponible ou inconnu.
class EtatPack {
  const EtatPack(this.pack, this.statut, this.telecharge, this.total);

  final String pack;
  final String statut;
  final int telecharge;
  final int total;

  bool get pret => statut == 'pret';

  bool get enCours =>
      statut == 'attente' || statut == 'wifi' || statut == 'telechargement' || statut == 'transfert';

  /// Avancement de 0 à 1, ou null s'il est inconnu.
  double? get avancement => total > 0 ? (telecharge / total).clamp(0.0, 1.0) : null;

  static EtatPack depuis(Object? brut, String pack) {
    if (brut is Map) {
      return EtatPack(
        '${brut['pack'] ?? pack}',
        '${brut['statut'] ?? 'inconnu'}',
        (brut['telecharge'] as num?)?.toInt() ?? 0,
        (brut['total'] as num?)?.toInt() ?? 0,
      );
    }
    return EtatPack(pack, 'indisponible', 0, 0);
  }
}

/// Pont vers le code Android (Play Asset Delivery et lecture des enregistrements). Hors Android,
/// ou sans Google Play, rien n'est disponible : l'application se rabat sur la synthèse vocale.
class AudioPacks {
  AudioPacks._();

  static const MethodChannel _canal = MethodChannel('dicoenfr/audio_packs');
  static const EventChannel _evenements = EventChannel('dicoenfr/audio_packs/events');

  static bool get disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _appeler<T>(String methode, Map<String, Object?> arguments) async {
    if (!disponible) return null;
    try {
      return await _canal.invokeMethod<T>(methode, arguments);
    } on MissingPluginException {
      return null; // version sans enregistrements
    } on PlatformException {
      return null;
    }
  }

  /// Chemin d'un fichier d'un pack, ou null s'il n'est pas disponible.
  static Future<String?> chemin(String pack, String fichier) =>
      _appeler<String>('chemin', {'pack': pack, 'fichier': fichier});

  static Future<bool> jouer(String chemin) async =>
      (await _appeler<bool>('jouer', {'chemin': chemin})) ?? false;

  static Future<EtatPack> statut(String pack) async =>
      EtatPack.depuis(await _appeler<Object>('statut', {'pack': pack}), pack);

  static Future<bool> telecharger(String pack) async =>
      (await _appeler<bool>('telecharger', {'pack': pack})) ?? false;

  static Future<void> supprimer(String pack) async {
    await _appeler<bool>('supprimer', {'pack': pack});
  }

  /// Affiche la demande d'accord de Google Play pour télécharger en données mobiles.
  static Future<void> confirmerDonneesMobiles() async {
    await _appeler<bool>('confirmer', {});
  }

  /// Progression des téléchargements en cours.
  static Stream<EtatPack> evenements() {
    if (!disponible) return const Stream<EtatPack>.empty();
    return _evenements
        .receiveBroadcastStream()
        .map((e) => EtatPack.depuis(e, ''))
        .handleError((Object _) {});
  }
}
