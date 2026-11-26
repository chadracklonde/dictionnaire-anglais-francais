import 'dart:async';

import 'package:flutter/material.dart';

import '../data/audio_index.dart';
import '../data/audio_packs.dart';

/// Réglages : enregistrements de prononciation (accent américain) livrés par Google Play.
class SectionPacksAudio extends StatefulWidget {
  const SectionPacksAudio({super.key});

  @override
  State<SectionPacksAudio> createState() => _SectionPacksAudioState();
}

class _SectionPacksAudioState extends State<SectionPacksAudio> {
  IndexAudio? _index;
  final Map<String, EtatPack> _etats = {};
  StreamSubscription<EtatPack>? _abonnement;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final index = await IndexAudio.obtenir();
    if (!mounted) return;
    setState(() => _index = index);
    for (final p in index.packs.where((p) => !p.coeur)) {
      final etat = await AudioPacks.statut(p.nom);
      if (!mounted) return;
      setState(() => _etats[p.nom] = etat);
    }
    _abonnement = AudioPacks.evenements().listen((etat) {
      if (!mounted || etat.pack.isEmpty) return;
      setState(() => _etats[etat.pack] = etat);
      if (etat.statut == 'confirmation') AudioPacks.confirmerDonneesMobiles();
    });
  }

  static String _mo(int octets) => '${(octets / 1048576).toStringAsFixed(octets < 10485760 ? 1 : 0)} Mo';

  Future<void> _telecharger(PackAudio pack) async {
    final ok = await AudioPacks.telecharger(pack.nom);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Téléchargement impossible : il faut installer l\'application depuis Google Play.'),
      ));
    }
  }

  Future<void> _supprimer(PackAudio pack) async {
    await AudioPacks.supprimer(pack.nom);
    final etat = await AudioPacks.statut(pack.nom);
    if (mounted) setState(() => _etats[pack.nom] = etat);
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    if (!AudioPacks.disponible || index == null || index.vide) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final coeur = index.packs.where((p) => p.coeur).toList();
    final facultatifs = index.packs.where((p) => !p.coeur).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Prononciation enregistrée', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          coeur.isEmpty
              ? 'Voix de contributeurs du Wiktionnaire (accent américain).'
              : 'Les ${coeur.first.fichiers} mots les plus courants ont une voix enregistrée '
                  '(accent américain), livrée avec l\'application. Les autres mots utilisent la '
                  'voix de votre téléphone, ou un pack facultatif ci-dessous.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (facultatifs.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Le téléchargement est fait par Google Play, une seule fois ; préférez le Wi-Fi.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        for (final pack in facultatifs) _lignePack(context, pack),
      ],
    );
  }

  Widget _lignePack(BuildContext context, PackAudio pack) {
    final etat = _etats[pack.nom];
    final numero = pack.nom.split('_').last;
    final titre = 'Pack $numero · ${pack.fichiers} mots · ${_mo(pack.octets)}';
    Widget action;
    String? detail;
    if (etat == null) {
      action = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (etat.pret) {
      detail = 'Téléchargé';
      action = TextButton(onPressed: () => _supprimer(pack), child: const Text('Supprimer'));
    } else if (etat.enCours) {
      detail = etat.statut == 'wifi'
          ? 'En attente du Wi-Fi'
          : etat.statut == 'attente'
              ? 'En attente…'
              : 'Téléchargement…';
      action = SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(value: etat.avancement, strokeWidth: 3),
      );
    } else if (etat.statut == 'indisponible') {
      detail = 'Disponible avec l\'application installée depuis Google Play';
      action = const SizedBox.shrink();
    } else {
      detail = etat.statut == 'echec' ? 'Échec du téléchargement' : null;
      action = FilledButton.tonal(
        onPressed: () => _telecharger(pack),
        child: const Text('Télécharger'),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titre),
      subtitle: detail == null ? null : Text(detail),
      trailing: action,
    );
  }
}
