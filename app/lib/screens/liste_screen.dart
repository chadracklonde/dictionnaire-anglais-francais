import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/user_store.dart';
import '../widgets/menu_mot.dart';
import '../widgets/mise_en_page.dart';
import 'entry_screen.dart';

/// Les mots d'une liste personnelle.
class ListeScreen extends StatelessWidget {
  const ListeScreen({super.key, required this.nom});

  final String nom;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final user = services.user;
    return Scaffold(
      appBar: AppBar(title: Text(nom)),
      body: ListenableBuilder(
        listenable: user,
        builder: (context, _) {
          final cles = user.listes[nom];
          if (cles == null || cles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cette liste est vide. Ouvrez une fiche et touchez « Listes » pour y ajouter le mot.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: padPage(context, v: 8),
            children: [
              for (final cle in List<String>.of(cles))
                Builder(builder: (context) {
                  final (mot, nature) = UserStore.decouper(cle);
                  return Dismissible(
                    key: ValueKey('$nom|$cle'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Theme.of(context).colorScheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline_rounded),
                    ),
                    onDismissed: (_) {
                      final position = cles.indexOf(cle);
                      final messenger = ScaffoldMessenger.of(context);
                      user.basculerDansListe(nom, cle);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: const Text('Retiré de la liste.'),
                          action: SnackBarAction(
                            label: 'Annuler',
                            onPressed: () =>
                                user.insererDansListe(nom, position < 0 ? 0 : position, cle),
                          ),
                        ));
                    },
                    child: ListTile(
                      title: Text(mot),
                      subtitle: Text(natureFr(nature)),
                      onLongPress: () => afficherMenuMot(context, mot),
                      onTap: () async {
                        final navigateur = Navigator.of(context);
                        final m = await services.resoudre(cle);
                        if (m == null) return;
                        navigateur
                            .push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: m)));
                      },
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
