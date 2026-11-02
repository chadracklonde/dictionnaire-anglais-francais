import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/mise_en_page.dart';
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
          OutlinedButton.icon(
            icon: const Icon(Icons.help_outline_rounded),
            label: const Text('Revoir le tutoriel'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const TutorialScreen())),
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
