import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/mise_en_page.dart';
import 'conjugation_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'index_screen.dart';
import 'reviser_screen.dart';

class _Onglet {
  const _Onglet(this.icone, this.iconeActif, this.libelle);

  final IconData icone;
  final IconData iconeActif;
  final String libelle;
}

const List<_Onglet> _onglets = [
  _Onglet(Icons.home_outlined, Icons.home_rounded, 'Accueil'),
  _Onglet(Icons.sort_by_alpha_rounded, Icons.sort_by_alpha_rounded, 'Index'),
  _Onglet(Icons.school_outlined, Icons.school_rounded, 'Réviser'),
  _Onglet(Icons.menu_book_outlined, Icons.menu_book_rounded, 'Conjugaison'),
  _Onglet(Icons.star_border_rounded, Icons.star_rounded, 'Favoris'),
];

/// Écran principal : cinq onglets dont l'état est conservé d'un onglet à l'autre. Barre en bas
/// sur téléphone, barre latérale sur grand écran (Windows, macOS, tablette).
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _onglet = 0;

  void _aller(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _onglet = i);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      // Ctrl+1 à Ctrl+5 (Cmd sur macOS) : changer d'onglet au clavier.
      bindings: {
        for (var i = 0; i < _onglets.length; i++) ...{
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true):
              () => _aller(i),
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), meta: true):
              () => _aller(i),
        },
      },
      child: PopScope(
        canPop: _onglet == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _onglet = 0);
        },
        child: LayoutBuilder(builder: (context, c) {
          final large = c.maxWidth >= largeurDeuxVolets;
          final corps = IndexedStack(
            index: _onglet,
            children: const [
              HomeScreen(),
              IndexScreen(),
              ReviserScreen(),
              ConjugationScreen(),
              FavoritesScreen(),
            ],
          );
          if (large) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _onglet,
                    onDestinationSelected: _aller,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final o in _onglets)
                        NavigationRailDestination(
                          icon: Icon(o.icone),
                          selectedIcon: Icon(o.iconeActif),
                          label: Text(o.libelle),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: AvecLargeurLocale(child: corps)),
                ],
              ),
            );
          }
          return Scaffold(
            body: corps,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _onglet,
              onDestinationSelected: _aller,
              destinations: [
                for (final o in _onglets)
                  NavigationDestination(
                    icon: Icon(o.icone),
                    selectedIcon: Icon(o.iconeActif),
                    label: o.libelle,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
