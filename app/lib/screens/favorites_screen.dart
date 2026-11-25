import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/user_store.dart';
import '../widgets/menu_mot.dart';
import '../widgets/mise_en_page.dart';
import 'entry_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoris'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Favoris'), Tab(text: 'Récents')],
          ),
        ),
        body: const TabBarView(
          children: [
            _Liste(favoris: true),
            _Liste(favoris: false),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.favoris});

  final bool favoris;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final user = services.user;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) => _contenu(context, services),
    );
  }

  Widget _contenu(BuildContext context, AppServices services) {
    final user = services.user;
    final cles = favoris ? user.favoris : user.historique;
    if (cles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            favoris
                ? 'Touchez l\'étoile d\'une fiche pour la retrouver ici.'
                : 'Les mots que vous consultez apparaissent ici.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: padPage(context, v: 8),
      children: [
        if (!favoris)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final copie = List<String>.of(user.historique);
                final messenger = ScaffoldMessenger.of(context);
                user.viderHistorique();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: const Text('Historique effacé.'),
                    action: SnackBarAction(
                      label: 'Annuler',
                      onPressed: () => user.restaurerHistorique(copie),
                    ),
                  ));
              },
              child: const Text('Vider l\'historique'),
            ),
          ),
        for (final cle in cles)
          Builder(builder: (context) {
            final (mot, nature) = UserStore.decouper(cle);
            final tuile = ListTile(
              title: Text(mot),
              subtitle: Text(natureFr(nature)),
              onLongPress: () => afficherMenuMot(context, mot),
              onTap: () async {
                final navigateur = Navigator.of(context);
                final m = await services.resoudre(cle);
                if (m == null) return;
                navigateur.push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: m)));
              },
            );
            if (!favoris) return tuile;
            return Dismissible(
              key: ValueKey(cle),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline_rounded),
              ),
              onDismissed: (_) {
                final position = user.favoris.indexOf(cle);
                final messenger = ScaffoldMessenger.of(context);
                user.basculerFavori(cle);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: const Text('Retiré des favoris.'),
                    action: SnackBarAction(
                      label: 'Annuler',
                      onPressed: () => user.insererFavori(position < 0 ? 0 : position, cle),
                    ),
                  ));
              },
              child: tuile,
            );
          }),
      ],
    );
  }
}
