import 'dart:async';

import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/speech.dart';
import '../data/user_store.dart';
import '../widgets/mise_en_page.dart';
import 'entry_screen.dart';

/// Expressions anglaises et leur équivalent français : idiomes, phrases utiles, proverbes, verbes à
/// particule. Recherche dans les deux langues, filtres par type et par thème.
class ExpressionsScreen extends StatefulWidget {
  const ExpressionsScreen({super.key, this.typeInitial = ''});

  final String typeInitial;

  @override
  State<ExpressionsScreen> createState() => _ExpressionsScreenState();
}

class _ExpressionsScreenState extends State<ExpressionsScreen> {
  static const int _page = 60;

  final _controleur = TextEditingController();
  Timer? _delai;
  late String _type = widget.typeInitial;
  String _theme = '';
  List<LigneExpression>? _lignes;
  bool _fini = false;
  bool _charge = false;
  int _jeton = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recharger());
  }

  @override
  void dispose() {
    _delai?.cancel();
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _recharger() async {
    final jeton = ++_jeton;
    setState(() {
      _lignes = null;
      _fini = false;
    });
    final lignes = await _lire(0);
    if (!mounted || jeton != _jeton) return;
    setState(() {
      _lignes = lignes;
      _fini = lignes.length < _page;
    });
  }

  Future<List<LigneExpression>> _lire(int decalage) async {
    try {
      return await AppScope.of(context).moteur.expressions(
            type: _type,
            theme: _theme,
            recherche: _controleur.text,
            limite: _page,
            decalage: decalage,
          );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _plus() async {
    final actuelles = _lignes;
    if (_charge || _fini || actuelles == null) return;
    _charge = true;
    final jeton = _jeton;
    final suite = await _lire(actuelles.length);
    _charge = false;
    if (!mounted || jeton != _jeton) return;
    setState(() {
      _lignes = [...actuelles, ...suite];
      _fini = suite.length < _page;
    });
  }

  void _surSaisie(String _) {
    _delai?.cancel();
    _delai = Timer(const Duration(milliseconds: 250), _recharger);
    setState(() {});
  }

  /// Thèmes proposés : ceux des phrases utiles, ou ceux des idiomes selon le type choisi.
  List<String> get _themes => switch (_type) {
        'utile' => const [
            'politesse', 'rencontre', 'voyage', 'hotel', 'restaurant', 'achats', 'sante', 'urgence',
            'telephone', 'travail'
          ],
        'idiome' || 'proverbe' => const [
            'corps', 'animaux', 'nourriture', 'meteo', 'argent', 'temps', 'travail', 'emotions',
            'communication', 'divers'
          ],
        _ => const [],
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lignes = _lignes;
    return Scaffold(
      appBar: AppBar(title: const Text('Expressions')),
      body: Column(
        children: [
          Padding(
            padding: padPage(context, v: 8),
            child: TextField(
              controller: _controleur,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Chercher une expression (anglais ou français)…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controleur.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controleur.clear();
                          _recharger();
                        },
                      ),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
              ),
              onChanged: _surSaisie,
              onSubmitted: (_) => _recharger(),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filtre('Tout', _type.isEmpty, () => _choisirType('')),
                for (final t in typesExpression)
                  _filtre(typeExpressionFr(t), _type == t, () => _choisirType(t)),
              ],
            ),
          ),
          if (_themes.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _filtre('Tous les thèmes', _theme.isEmpty, () => _choisirTheme('')),
                  for (final t in _themes)
                    _filtre(themesExpression[t] ?? t, _theme == t, () => _choisirTheme(t)),
                ],
              ),
            ),
          Expanded(
            child: lignes == null
                ? const Center(child: CircularProgressIndicator())
                : lignes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Aucune expression trouvée.',
                              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.builder(
                        padding: padPage(context, v: 4),
                        itemCount: lignes.length + (_fini ? 0 : 1),
                        itemBuilder: (context, i) {
                          if (i >= lignes.length) {
                            WidgetsBinding.instance.addPostFrameCallback((_) => _plus());
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return CarteExpression(ligne: lignes[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filtre(String texte, bool actif, VoidCallback surAppui) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: ChoiceChip(label: Text(texte), selected: actif, onSelected: (_) => surAppui()),
      );

  void _choisirType(String type) {
    _type = type;
    _theme = '';
    _recharger();
  }

  void _choisirTheme(String theme) {
    _theme = theme;
    _recharger();
  }
}

/// Une expression dans une liste : l'anglais, l'équivalent français recommandé, le sens littéral.
class CarteExpression extends StatelessWidget {
  const CarteExpression({super.key, required this.ligne});

  final LigneExpression ligne;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registre = registreFr(ligne.registre);
    final user = AppScope.of(context).user;
    final cle = UserStore.cle(ligne.mot.mot, ligne.mot.nature);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: ligne.mot))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ligne.mot.mot,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Écouter',
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => speech.speak(ligne.mot.mot, accent: user.accent),
                  ),
                  ListenableBuilder(
                    listenable: user,
                    builder: (context, _) {
                      final actif = user.estFavori(cle);
                      return IconButton(
                        tooltip: actif ? 'Retirer des favoris' : 'Ajouter aux favoris (à réviser)',
                        icon: Icon(actif ? Icons.star_rounded : Icons.star_border_rounded),
                        onPressed: () => user.basculerFavori(cle),
                      );
                    },
                  ),
                ],
              ),
              if (ligne.fr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(ligne.fr, style: theme.textTheme.bodyLarge),
              ],
              if (ligne.litteral.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Mot à mot : ${ligne.litteral}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 4),
              Text(
                [typeExpressionUnFr(ligne.type), if (registre.isNotEmpty) registre].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
