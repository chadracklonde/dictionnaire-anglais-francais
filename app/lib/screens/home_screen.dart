import 'dart:async';

import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/mots_du_jour.dart';
import '../data/user_store.dart';
import 'definition_screen.dart';
import 'entry_screen.dart';
import 'favorites_screen.dart';
import 'index_screen.dart';
import 'motif_screen.dart';
import 'notes_screen.dart';
import 'result_screen.dart';
import 'revision_session_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import '../widgets/listes.dart';
import '../widgets/menu_mot.dart';
import '../widgets/mise_en_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controleur = TextEditingController();
  final _focus = FocusNode();
  final _defilement = ScrollController();
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
    _focus.dispose();
    _defilement.dispose();
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
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Moteur.estMotif(t) ? MotifScreen(motif: t) : ResultScreen(requete: t),
    ));
  }

  void _ouvrir(Widget ecran) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  /// Icône de la barre : ramène en haut de l'accueil et active la recherche.
  void _activerRecherche() {
    if (_defilement.hasClients) {
      _defilement.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
    _focus.requestFocus();
  }

  Future<void> _rechercheParMotif() async {
    final texte = await demanderTexte(
      context,
      titre: 'Recherche par motif',
      indication: 'inter*   ·   *tion   ·   c?t',
      max: 40,
    );
    if (texte == null || texte.trim().isEmpty || !mounted) return;
    var motif = texte.trim();
    // Sans joker, on cherche les mots qui commencent par ce texte.
    if (!Moteur.estMotif(motif)) motif = '$motif*';
    _ouvrir(MotifScreen(motif: motif));
  }

  Future<void> _motAuHasard() async {
    try {
      final mots = await AppScope.of(context).source.motsHasard(1);
      if (!mounted) return;
      if (mots.isEmpty) {
        _message('Aucun mot trouvé, réessayez.');
        return;
      }
      _ouvrir(ResultScreen(requete: mots.first));
    } catch (_) {
      if (mounted) _message('Impossible de tirer un mot pour le moment.');
    }
  }

  void _reviserFavoris() {
    final user = AppScope.of(context).user;
    if (user.favoris.isEmpty) {
      _message('Ajoutez d\'abord des mots à vos favoris (l\'étoile d\'une fiche).');
      return;
    }
    final dues = user.aReviser(user.favoris);
    if (dues.isEmpty) {
      _message('Rien à réviser aujourd\'hui dans vos favoris. Revenez demain !');
      return;
    }
    _ouvrir(RevisionSessionScreen(cles: dues));
  }

  Widget _outil(ThemeData theme, IconData icone, String texte, VoidCallback surAppui) {
    return ActionChip(
      avatar: Icon(icone, size: 22, color: theme.colorScheme.primary),
      label: Text(texte, style: theme.textTheme.bodyLarge),
      onPressed: surAppui,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }

  Widget _lettre(ThemeData theme, String lettre) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        onPressed: () => _ouvrir(IndexScreen(lettreInitiale: lettre.toLowerCase())),
        child: Text(
          lettre,
          style: theme.textTheme.titleLarge
              ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AppScope.of(context).user;
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focus.requestFocus,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focus.requestFocus,
        },
        child: Scaffold(
      appBar: AppBar(
        title: const Text('Anglais Français'),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search_rounded),
            onPressed: _activerRecherche,
          ),
          IconButton(
            tooltip: 'Favoris',
            icon: const Icon(Icons.star_border_rounded),
            onPressed: () => _ouvrir(const FavoritesScreen()),
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _ouvrir(const SettingsScreen()),
          ),
        ],
      ),
      body: ListView(
        controller: _defilement,
        padding: padPage(context),
        children: [
          TextField(
            controller: _controleur,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'Rechercher un mot…',
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
          const SizedBox(height: 20),
          Builder(builder: (context) {
            final mot = motDuJour(DateTime.now());
            final couleurs = theme.colorScheme;
            return Semantics(
              button: true,
              label: 'Mot du jour : $mot',
              excludeSemantics: true,
              child: Material(
                color: couleurs.primaryContainer,
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _chercher(mot),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mot du jour',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: couleurs.onPrimaryContainer)),
                        const SizedBox(height: 12),
                        Text(mot,
                            style: theme.textTheme.displaySmall?.copyWith(
                                color: couleurs.onPrimaryContainer, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 28),
          Text('Outils', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _outil(theme, Icons.grid_view_rounded, 'Recherche par motif', _rechercheParMotif),
              _outil(theme, Icons.shuffle_rounded, 'Mot au hasard', _motAuHasard),
              _outil(theme, Icons.edit_note_rounded, 'Mes notes', () => _ouvrir(const NotesScreen())),
              _outil(theme, Icons.school_outlined, 'Réviser mes favoris', _reviserFavoris),
              _outil(theme, Icons.manage_search_rounded, 'Chercher par définition',
                  () => _ouvrir(const DefinitionScreen())),
            ],
          ),
          const SizedBox(height: 28),
          Text('Index alphabétique', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) _lettre(theme, l)],
          ),
          const SizedBox(height: 28),
          Text('Récemment consultés', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (user.historique.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final cle in _recents(user))
                  GestureDetector(
                    onLongPress: () => afficherMenuMot(context, UserStore.decouper(cle).$1),
                    child: ActionChip(
                      label: Text(UserStore.decouper(cle).$1, style: theme.textTheme.bodyLarge),
                      onPressed: () => _ouvrirCle(cle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
              ],
            )
          else
            Text(
              'Les mots que vous consultez apparaissent ici. Tout fonctionne sans connexion.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
    ));
  }

  /// Les derniers mots consultés, sans répéter deux fois le même mot.
  List<String> _recents(UserStore user) {
    final vus = <String>{};
    final sortie = <String>[];
    for (final cle in user.historique) {
      if (vus.add(UserStore.decouper(cle).$1.toLowerCase())) sortie.add(cle);
      if (sortie.length >= 12) break;
    }
    return sortie;
  }

  Future<void> _ouvrirCle(String cle) async {
    final navigateur = Navigator.of(context);
    final mot = await AppScope.of(context).resoudre(cle);
    if (mot == null || !mounted) return;
    navigateur.push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: mot)));
  }
}
