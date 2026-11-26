import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/user_store.dart';
import '../widgets/mise_en_page.dart';
import 'entry_screen.dart';

/// Tous les mots pour lesquels on a écrit une note.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final user = services.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes notes')),
      body: ListenableBuilder(
        listenable: user,
        builder: (context, _) {
          final cles = user.notes.keys.toList()
            ..sort((a, b) => UserStore.decouper(a).$1.toLowerCase().compareTo(
                UserStore.decouper(b).$1.toLowerCase()));
          if (cles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune note pour l\'instant. Ouvrez une fiche et touchez « Ajouter une note » '
                  'pour écrire un exemple ou une astuce.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: padPage(context, v: 8),
            children: [
              for (final cle in cles)
                Builder(builder: (context) {
                  final (mot, nature) = UserStore.decouper(cle);
                  final note = user.noteDe(cle);
                  return ListTile(
                    title: Text('$mot · ${natureFr(nature)}'),
                    subtitle: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Supprimer la note',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        user.definirNote(cle, '');
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: const Text('Note supprimée.'),
                            action: SnackBarAction(
                              label: 'Annuler',
                              onPressed: () => user.definirNote(cle, note),
                            ),
                          ));
                      },
                    ),
                    onTap: () async {
                      final navigateur = Navigator.of(context);
                      final m = await services.resoudre(cle);
                      if (m == null) return;
                      navigateur
                          .push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: m)));
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
