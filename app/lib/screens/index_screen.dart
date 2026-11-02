import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
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
  String _lettre = 'a';
  final List<EntreeIndex> _entrees = [];
  bool _charge = false;
  bool _fini = false;

  /// Clé située juste avant tous les mots de la lettre.
  static String _curseurInitial(String lettre) {
    final avant = lettre == 'a' ? '`' : String.fromCharCode(lettre.codeUnitAt(0) - 1);
    return '$avant￿';
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
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _recommencer(String lettre) async {
    setState(() {
      _lettre = lettre;
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
    final apres = _entrees.isEmpty ? _curseurInitial(lettre) : _entrees.last.cle;
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
          Expanded(
            child: _entrees.isEmpty && !_fini
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _defilement,
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
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ResultScreen(requete: e.mot),
                        )),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
