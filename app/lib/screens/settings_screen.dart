import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../widgets/mise_en_page.dart';
import '../widgets/packs_audio.dart';
import 'about_screen.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: padPage(context),
        children: [
          Text('Thème', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('Système')),
              ButtonSegment(value: 'light', label: Text('Clair')),
              ButtonSegment(value: 'dark', label: Text('Sombre')),
            ],
            selected: {user.themeMode},
            onSelectionChanged: (s) => user.setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          Text('Taille du texte', style: theme.textTheme.titleMedium),
          Slider(
            value: user.textScale,
            min: 0.85,
            max: 1.6,
            divisions: 5,
            label: '${(user.textScale * 100).round()} %',
            onChanged: user.setTextScale,
          ),
          const SizedBox(height: 16),
          Text('Voix anglaise', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'us', label: Text('Américain')),
              ButtonSegment(value: 'uk', label: Text('Britannique')),
            ],
            selected: {user.accent},
            onSelectionChanged: (s) => user.setAccent(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            'La prononciation utilise la synthèse vocale de votre téléphone.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('Apprentissage', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Objectif du jour (réponses)', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 10, label: Text('10')),
              ButtonSegment(value: 20, label: Text('20')),
              ButtonSegment(value: 30, label: Text('30')),
            ],
            selected: {user.objectifJour},
            onSelectionChanged: (s) => user.setObjectifJour(s.first),
          ),
          const SizedBox(height: 12),
          Text('Nouveaux mots par jour', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 10, label: Text('10')),
              ButtonSegment(value: 20, label: Text('20')),
              ButtonSegment(value: 50, label: Text('50')),
            ],
            selected: {user.nouveauxParJour},
            onSelectionChanged: (s) => user.setNouveauxParJour(s.first),
          ),
          const SizedBox(height: 4),
          Text(
            'Les nouveaux mots arrivent au fur et à mesure, pour ne pas se décourager.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('Expressions', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Afficher les expressions vulgaires'),
            subtitle: const Text('Masquées par défaut : jurons et expressions grossières.'),
            value: user.afficherVulgaire,
            onChanged: user.setAfficherVulgaire,
          ),
          const SectionPacksAudio(),
          const SizedBox(height: 24),
          Text('Sauvegarde', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Vos favoris, notes et listes restent sur ce téléphone. Pour les garder en cas de '
            'changement d\'appareil, exportez-les puis collez le texte dans une note ou un message à '
            'vous-même, et importez-le sur le nouvel appareil.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Exporter'),
                onPressed: () async {
                  final texte = user.exporter();
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: texte));
                  messenger.showSnackBar(const SnackBar(content: Text('Sauvegarde copiée.')));
                  await Share.share(texte);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Importer (texte copié)'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final presse = await Clipboard.getData('text/plain');
                  final texte = presse?.text ?? '';
                  try {
                    final r = await user.importer(texte);
                    messenger.showSnackBar(SnackBar(
                      content: Text('Importé : ${r.favoris} favori(s), ${r.notes} note(s), '
                          '${r.listes} nouvelle(s) liste(s).'),
                    ));
                  } on FormatException catch (e) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('${e.message} Copiez d\'abord le texte exporté.'),
                    ));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.help_outline_rounded),
            label: const Text('Revoir le tutoriel'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const TutorialScreen())),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('À propos et licences'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Vider l\'historique'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await user.viderHistorique();
              messenger.showSnackBar(const SnackBar(content: Text('Historique vidé.')));
            },
          ),
        ],
      ),
    );
  }
}
