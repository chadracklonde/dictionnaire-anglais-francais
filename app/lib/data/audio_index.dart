import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Un enregistrement : pack qui le contient, nom du fichier, auteur et licence.
class EntreeAudio {
  const EntreeAudio({
    required this.pack,
    required this.fichier,
    required this.auteur,
    required this.licence,
    required this.licenceUrl,
    required this.page,
  });

  final String pack;
  final String fichier;
  final String auteur;
  final String licence;
  final String licenceUrl;
  final String page;

  /// Texte de crédit : « Voix : Auteur · CC BY-SA 4.0 ».
  String get credit {
    final qui = auteur.isEmpty ? 'enregistrement du Wiktionnaire' : auteur;
    return licence.isEmpty ? 'Voix : $qui' : 'Voix : $qui · $licence';
  }
}

/// Un pack d'enregistrements : [coeur] vaut vrai pour celui qui est livré avec l'application.
class PackAudio {
  const PackAudio({required this.nom, required this.fichiers, required this.octets, required this.coeur});

  final String nom;
  final int fichiers;
  final int octets;
  final bool coeur;
}

Map<String, Object?> _analyser(String texte) {
  final data = jsonDecode(texte);
  return data is Map<String, Object?> ? data : const <String, Object?>{};
}

/// Index des enregistrements, lu dans assets/audio/audio_index.json (produit par la CI).
/// Absent dans une version sans enregistrements : tout est alors vide.
class IndexAudio {
  IndexAudio._(this._fichiers, this.packs);

  final Map<String, Object?> _fichiers;
  final List<PackAudio> packs;

  static IndexAudio aucun() => IndexAudio._(const {}, const []);

  static Future<IndexAudio>? _chargement;

  static Future<IndexAudio> obtenir() => _chargement ??= _lire();

  static Future<IndexAudio> _lire() async {
    try {
      final texte = await rootBundle.loadString('assets/audio/audio_index.json');
      final data = await compute(_analyser, texte);
      final fichiers = data['fichiers'];
      final packs = data['packs'];
      return IndexAudio._(
        fichiers is Map<String, Object?> ? fichiers : const {},
        [
          if (packs is Map)
            for (final e in packs.entries)
              if (e.value is Map)
                PackAudio(
                  nom: '${e.key}',
                  fichiers: ((e.value as Map)['fichiers'] as num?)?.toInt() ?? 0,
                  octets: ((e.value as Map)['octets'] as num?)?.toInt() ?? 0,
                  coeur: (e.value as Map)['coeur'] == true,
                ),
        ]..sort((a, b) => a.coeur != b.coeur ? (a.coeur ? -1 : 1) : a.nom.compareTo(b.nom)),
      );
    } catch (_) {
      return IndexAudio.aucun();
    }
  }

  bool get vide => _fichiers.isEmpty;

  /// L'enregistrement d'un fichier du Wiktionnaire (nom Commons), s'il est dans un pack.
  EntreeAudio? entree(String fichier) {
    final e = _fichiers[fichier];
    if (e is! Map) return null;
    String t(String k) => (e[k] as String?) ?? '';
    final pack = t('p');
    final nom = t('f');
    if (pack.isEmpty || nom.isEmpty) return null;
    return EntreeAudio(
      pack: pack,
      fichier: nom,
      auteur: t('a'),
      licence: t('l'),
      licenceUrl: t('u'),
      page: t('d'),
    );
  }
}
