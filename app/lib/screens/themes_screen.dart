import 'package:flutter/material.dart';

import '../app.dart';
import '../data/themes.dart';
import '../data/user_store.dart';
import '../widgets/mise_en_page.dart';
import 'liste_screen.dart';

/// Listes de vocabulaire prêtes à l'emploi : un appui les copie dans vos listes.
class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  String? _enCours;

  Future<void> _ajouter(String theme, List<String> mots) async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigateur = Navigator.of(context);
    final nom = 'Thème · $theme';
    setState(() => _enCours = theme);
    await services.user.creerListe(nom); // déjà là : on complète la liste
    var ajoutes = 0;
    for (final texte in mots) {
      final mot = await services.motParTexte(texte);
      if (mot == null) continue;
      final cle = UserStore.cle(mot.mot, mot.nature);
      if (!services.user.estDansListe(nom, cle)) {
        await services.user.basculerDansListe(nom, cle);
        ajoutes++;
      }
    }
    if (!mounted) return;
    setState(() => _enCours = null);
    messenger.showSnackBar(SnackBar(
      content: Text(ajoutes == 0
          ? 'La liste « $nom » est déjà complète.'
          : '$ajoutes mot(s) ajouté(s) à la liste « $nom ».'),
    ));
    navigateur.push(MaterialPageRoute<void>(builder: (_) => ListeScreen(nom: nom)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listes de vocabulaire')),
      body: ListView(
        padding: padPage(context, v: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Touchez un thème pour en faire une liste personnelle. Vous pourrez ensuite '
              'réviser ses mots (onglet Réviser) ou faire un quiz.',
            ),
          ),
          for (final entree in themes.entries)
            ListTile(
              leading: const Icon(Icons.list_alt_rounded),
              title: Text(entree.key),
              subtitle: Text('${entree.value.length} mots'),
              trailing: _enCours == entree.key
                  ? const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded),
              onTap: _enCours != null ? null : () => _ajouter(entree.key, entree.value),
            ),
        ],
      ),
    );
  }
}
