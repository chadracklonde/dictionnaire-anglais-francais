import 'dart:async';

import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/menu_mot.dart';
import '../widgets/mise_en_page.dart';
import 'motif_screen.dart';
import 'result_screen.dart';

/// Index alphabétique des mots anglais, par lettre, paginé par curseur.
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  static const int _page = 100;
  static const String _lettres = 'abcdefghijklmnopqrstuvwxyz';

  final _defilement = ScrollController();
  final _recherche = TextEditingController();
  Timer? _delai;
  List<String> _suggestions = const [];
  String _lettre = 'a';
  String _debut = 'a';
  final List<EntreeIndex> _entrees = [];
  bool _charge = false;
  bool _fini = false;

  /// Clé située juste avant tous les mots qui commencent par [debut] (une ou deux lettres).
  static String _curseurInitial(String debut) {
    final c = debut.codeUnitAt(debut.length - 1);
    final avant = c == 0x61 ? '`' : String.fromCharCode(c - 1);
    return '${debut.substring(0, debut.length - 1)}$avant\uffff';
  }

  @override
  void initState() {
    super.initState();
    _defilement.addListener(() {
      if (_defilement.position.extentAfter < 600) _suite();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recommencer('a'));
  }

  @override
  void dispose() {
    _delai?.cancel();
    _recherche.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _surSaisie(String texte) {
    setState(() {});
    _delai?.cancel();
    if (texte.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _delai = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      final liste = await AppScope.of(context).moteur.suggerer(texte);
      if (!mounted || _recherche.text != texte) return;
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

  Future<void> _recommencer(String lettre, {String? debut}) async {
    setState(() {
      _lettre = lettre;
      _debut = debut ?? lettre;
      _entrees.clear();
      _fini = false;
    });
    if (_defilement.hasClients) _defilement.jumpTo(0);
    await _suite();
  }

  Future<void> _suite() async {
    if (_charge || _fini) return;
    _charge = true;
    final lettre = _lettre;
    final apres = _entrees.isEmpty ? _curseurInitial(_debut) : _entrees.last.cle;
    final page = await AppScope.of(context).source.indexAnglais(apres, _page);
    _charge = false;
    if (!mounted || lettre != _lettre) return;
    setState(() {
      for (final e in page) {
        if (!e.cle.startsWith(lettre)) {
          _fini = true;
          break;
        }
        _entrees.add(e);
      }
      if (page.length < _page) _fini = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Index')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _recherche,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'Un mot anglais ou français',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _recherche.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _recherche.clear();
                          _suggestions = const [];
                        }),
                      ),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
              ),
              onChanged: _surSaisie,
              onSubmitted: _chercher,
            ),
          ),
          if (_suggestions.isNotEmpty && _recherche.text.trim().isNotEmpty)
            Expanded(
              child: ListView(
                padding: padPage(context, v: 0),
                children: [
                  for (final s in _suggestions)
                    ListTile(
                      dense: true,
                      title: Text(s),
                      onLongPress: () => afficherMenuMot(context, s),
                      onTap: () {
                        _recherche.text = s;
                        _chercher(s);
                      },
                    ),
                ],
              ),
            )
          else ...[
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                for (final l in _lettres.split(''))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(l.toUpperCase()),
                      selected: l == _lettre,
                      onSelected: (_) => _recommencer(l),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text('${_lettre.toUpperCase()}…'),
                    selected: _debut == _lettre,
                    onSelected: (_) => _recommencer(_lettre),
                  ),
                ),
                for (final l in _lettres.split(''))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text('$_lettre$l'),
                      selected: _debut == '$_lettre$l',
                      onSelected: (_) => _recommencer(_lettre, debut: '$_lettre$l'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _entrees.isEmpty && !_fini
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _defilement,
                    padding: padPage(context, v: 0),
                    itemCount: _entrees.length + (_fini ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (i >= _entrees.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final e = _entrees[i];
                      return ListTile(
                        dense: true,
                        title: Text(e.mot, style: theme.textTheme.bodyLarge),
                        onLongPress: () => afficherMenuMot(context, e.mot),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ResultScreen(requete: e.mot),
                        )),
                      );
                    },
                  ),
          ),
          ],
        ],
      ),
    );
  }
}
