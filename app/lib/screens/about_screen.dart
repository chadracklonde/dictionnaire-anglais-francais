import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/format.dart';
import '../widgets/mise_en_page.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Future<Map<String, int>>? _chiffres;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chiffres ??= AppScope.of(context).source.chiffres();
  }

  Future<void> _ouvrir(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: padPage(context),
        children: [
          Text('Dictionnaire Anglais-Français', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Version $appVersion · par Chadrack Londe, Kindu (RDC)'),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, int>>(
            future: _chiffres,
            builder: (context, snap) {
              final c = snap.data;
              if (c == null || c.isEmpty) return const SizedBox.shrink();
              return Text(
                '${formatCount(c['mots'] ?? 0)} mots · ${formatCount(c['traductions'] ?? 0)} traductions · '
                '${formatCount(c['verbes'] ?? 0)} verbes',
                style: theme.textTheme.titleSmall,
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Application 100 % hors ligne : aucun compte, aucune publicité, aucune donnée '
            'envoyée. Vos favoris et votre historique restent sur cet appareil.',
          ),
          const SizedBox(height: 20),
          Text('Sources et licences', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Les mots, définitions, traductions, formes et prononciations viennent du '
            'Wiktionnaire (anglais et français), publié sous licence Creative Commons '
            'Attribution – Partage dans les mêmes conditions 4.0 (CC BY-SA 4.0). Les données '
            'ont été extraites et adaptées (fusion des deux éditions, sélection, renvois '
            'de formes) ; la base de cette application reste sous la même licence.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Extraction : projet wiktextract / kaikki.org. Fréquences des mots : wordfreq.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _ouvrir('https://creativecommons.org/licenses/by-sa/4.0/deed.fr'),
                child: const Text('Licence CC BY-SA 4.0'),
              ),
              OutlinedButton(
                onPressed: () => _ouvrir('https://fr.wiktionary.org'),
                child: const Text('Wiktionnaire'),
              ),
              OutlinedButton(
                onPressed: () => _ouvrir('https://kaikki.org'),
                child: const Text('kaikki.org'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Licences des bibliothèques'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Dictionnaire Anglais-Français',
              applicationVersion: appVersion,
            ),
          ),
        ],
      ),
    );
  }
}
