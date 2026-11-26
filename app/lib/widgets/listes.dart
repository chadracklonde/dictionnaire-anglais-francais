import 'package:flutter/material.dart';

import '../app.dart';

/// Demande un texte à l'utilisateur ; renvoie null s'il annule.
Future<String?> demanderTexte(
  BuildContext context, {
  required String titre,
  String initial = '',
  String indication = '',
  int lignes = 1,
  int max = 200,
}) {
  final controleur = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: TextField(
        controller: controleur,
        autofocus: true,
        minLines: lignes,
        maxLines: lignes == 1 ? 1 : lignes + 3,
        maxLength: max,
        decoration: InputDecoration(hintText: indication),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controleur.text),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

/// Crée une liste après avoir demandé son nom ; affiche un message si le nom est refusé.
Future<void> creerListeAvecDialogue(BuildContext context) async {
  final user = AppScope.of(context).user;
  final messenger = ScaffoldMessenger.of(context);
  final nom = await demanderTexte(
    context,
    titre: 'Nouvelle liste',
    indication: 'Par exemple : à réviser',
    max: 60,
  );
  if (nom == null) return;
  final ok = await user.creerListe(nom);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Nom vide ou déjà utilisé.'),
    ));
  }
}

/// Choisir les listes qui contiennent un mot.
Future<void> afficherChoixListes(BuildContext context, String cle) {
  final user = AppScope.of(context).user;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListenableBuilder(
        listenable: user,
        builder: (context, _) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text('Ajouter à une liste', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final nom in user.listes.keys)
                CheckboxListTile(
                  title: Text(nom),
                  value: user.estDansListe(nom, cle),
                  onChanged: (_) => user.basculerDansListe(nom, cle),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Nouvelle liste'),
                onTap: () => creerListeAvecDialogue(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
