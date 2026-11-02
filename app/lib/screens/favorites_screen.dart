import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/user_store.dart';
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
      children: [
        if (!favoris)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: user.viderHistorique,
              child: const Text('Vider l\'historique'),
            ),
          ),
        for (final cle in cles)
          Builder(builder: (context) {
            final (mot, nature) = UserStore.decouper(cle);
            return ListTile(
              title: Text(mot),
              subtitle: Text(natureFr(nature)),
              onTap: () async {
                final navigateur = Navigator.of(context);
                final m = await services.resoudre(cle);
                if (m == null) return;
                navigateur.push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: m)));
              },
            );
          }),
      ],
    );
  }
}
