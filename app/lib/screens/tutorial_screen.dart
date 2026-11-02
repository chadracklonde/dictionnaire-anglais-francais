import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/mise_en_page.dart';

class _Page {
  const _Page(this.icone, this.titre, this.texte);

  final IconData icone;
  final String titre;
  final String texte;
}

const List<_Page> _pages = [
  _Page(
    Icons.search_rounded,
    'Cherchez dans les deux sens',
    'Tapez un mot anglais ou français. Les formes conjuguées ou au pluriel (went, teeth, '
        'children…) mènent au mot de base. Deux onglets montrent anglais → français et '
        'français → anglais.',
  ),
  _Page(
    Icons.translate_rounded,
    'L\'équivalent français d\'abord',
    'Chaque fiche affiche les équivalents français en premier. Touchez « Définitions en '
        'anglais » pour déplier le détail, avec des exemples. Le haut-parleur lit le mot à voix haute.',
  ),
  _Page(
    Icons.menu_book_rounded,
    'Conjugaison anglaise',
    'Sur la fiche d\'un verbe, « Conjuguer » donne tous les temps, en phrase affirmative, '
        'négative ou en question. Vous pouvez copier le résultat.',
  ),
  _Page(
    Icons.cloud_off_rounded,
    'Tout reste sur votre appareil',
    'Aucune connexion, aucun compte, aucune publicité. Les étoiles gardent vos favoris, '
        'l\'index permet de parcourir les mots par lettre.',
  ),
];

/// Présentation affichée au premier lancement ; reste accessible depuis les réglages.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controleur = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    await AppScope.of(context).user.setTutorielVu();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final derniere = _page == _pages.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenue'),
        automaticallyImplyLeading: false,
        actions: [
          if (!derniere) TextButton(onPressed: _terminer, child: const Text('Passer', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controleur,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final p in _pages)
                  Center(
                    child: SingleChildScrollView(
                      padding: padPage(context, v: 24).copyWith(left: 32, right: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.icone, size: 72, color: theme.colorScheme.primary),
                            const SizedBox(height: 24),
                            Semantics(
                              header: true,
                              child: Text(
                                p.titre,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(p.texte, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                Semantics(
                  label: 'Page ${_page + 1} sur ${_pages.length}',
                  child: Row(
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: derniere
                      ? _terminer
                      : () => _controleur.nextPage(
                            duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: Text(derniere ? 'Commencer' : 'Suivant'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
