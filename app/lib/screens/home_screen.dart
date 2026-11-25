import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/mots_du_jour.dart';
import '../data/user_store.dart';
import 'about_screen.dart';
import 'entry_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import '../widgets/menu_mot.dart';
import '../widgets/mise_en_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controleur = TextEditingController();
  Timer? _delai;
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || AppScope.of(context).user.tutorielVu) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TutorialScreen()));
    });
  }

  @override
  void dispose() {
    _delai?.cancel();
    _controleur.dispose();
    super.dispose();
  }

  void _surSaisie(String texte) {
    _delai?.cancel();
    _delai = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      final moteur = AppScope.of(context).moteur;
      final liste = await moteur.suggerer(texte);
      if (!mounted || _controleur.text != texte) return;
      setState(() => _suggestions = liste);
    });
  }

  void _chercher(String texte) {
    final t = texte.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ResultScreen(requete: t)));
  }

  void _ouvrir(Widget ecran) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AppScope.of(context).user;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Anglais Français'),
        actions: [
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _ouvrir(const SettingsScreen()),
          ),
          IconButton(
            tooltip: 'À propos',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _ouvrir(const AboutScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: padPage(context),
        children: [
          TextField(
            controller: _controleur,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'Un mot anglais ou français',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controleur.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _controleur.clear();
                        _suggestions = const [];
                      }),
                    ),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
            ),
            onChanged: (t) {
              setState(() {});
              _surSaisie(t);
            },
            onSubmitted: _chercher,
          ),
          if (_suggestions.isNotEmpty && _controleur.text.trim().isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (final s in _suggestions)
                    ListTile(
                      dense: true,
                      title: Text(s),
                      onTap: () {
                        _controleur.text = s;
                        _chercher(s);
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final mot = motDuJour(DateTime.now());
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.primary),
                title: Text(mot),
                subtitle: const Text('Mot du jour'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chercher(mot),
              ),
            );
          }),
          const SizedBox(height: 24),
          if (user.historique.isNotEmpty) ...[
            Text('Récemment consultés', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final cle in user.historique.take(8))
              Builder(builder: (context) {
                final (mot, nature) = UserStore.decouper(cle);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(mot),
                  subtitle: Text(natureFr(nature)),
                  onTap: () => _ouvrirCle(cle),
                  onLongPress: () => afficherMenuMot(context, mot),
                );
              }),
          ] else
            Text(
              'Tapez un mot pour commencer. Tout fonctionne sans connexion.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    ),
    );
  }

  Future<void> _ouvrirCle(String cle) async {
    final navigateur = Navigator.of(context);
    final mot = await AppScope.of(context).resoudre(cle);
    if (mot == null || !mounted) return;
    navigateur.push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: mot)));
  }
}
