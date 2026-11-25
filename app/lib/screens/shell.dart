import 'package:flutter/material.dart';

import 'conjugation_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'index_screen.dart';
import 'reviser_screen.dart';

/// Écran principal : quatre onglets en bas, dont l'état est conservé d'un onglet à l'autre.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _onglet == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _onglet = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _onglet,
          children: const [
            HomeScreen(),
            IndexScreen(),
            ReviserScreen(),
            ConjugationScreen(),
            FavoritesScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: (i) {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _onglet = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.sort_by_alpha_rounded),
              label: 'Index',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Réviser',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Conjugaison',
            ),
            NavigationDestination(
              icon: Icon(Icons.star_border_rounded),
              selectedIcon: Icon(Icons.star_rounded),
              label: 'Favoris',
            ),
          ],
        ),
      ),
    );
  }
}
