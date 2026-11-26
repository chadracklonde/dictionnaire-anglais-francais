import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/speech.dart';
import '../widgets/mise_en_page.dart';

/// Dictée : on entend un mot ou une expression anglaise et on l'écrit. Rien n'est envoyé nulle part.
class DicteeScreen extends StatefulWidget {
  const DicteeScreen({super.key, this.expressions = false});

  /// Dicter des expressions plutôt que des mots.
  final bool expressions;

  @override
  State<DicteeScreen> createState() => _DicteeScreenState();
}

class _DicteeScreenState extends State<DicteeScreen> {
  static const int _nombre = 10;

  final _controleur = TextEditingController();
  List<String>? _items;
  int _courant = 0;
  int _score = 0;
  bool _verifie = false;
  bool _juste = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparer());
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _preparer() async {
    final source = AppScope.of(context).source;
    List<String> items;
    try {
      if (widget.expressions) {
        final lignes = await source.expressionsCureesHasard(_nombre + 4);
        items = [
          for (final e in lignes)
            if (e.mot.mot.length <= 40) e.mot.mot
        ];
      } else {
        items = [
          for (final m in await source.motsHasard(_nombre + 6))
            if (m.length >= 3) m
        ];
      }
    } catch (_) {
      items = const [];
    }
    if (!mounted) return;
    setState(() => _items = items.take(_nombre).toList());
    _ecouter();
  }

  void _ecouter() {
    final items = _items;
    if (items == null || _courant >= items.length) return;
    speech.speak(items[_courant], accent: AppScope.of(context).user.accent);
  }

  /// Texte comparable : sans accents, majuscules, ponctuation ni espaces en trop.
  static String _clef(String texte) => plier(texte)
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^a-z0-9' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _verifier() {
    final cible = _items![_courant];
    final juste = _clef(_controleur.text) == _clef(cible);
    setState(() {
      _verifie = true;
      _juste = juste;
      if (juste) _score++;
    });
  }

  void _suivant() {
    setState(() {
      _courant++;
      _verifie = false;
      _controleur.clear();
    });
    _ecouter();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    final titre = widget.expressions ? 'Dictée d\'expressions' : 'Dictée de mots';
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Pas assez de mots pour une dictée.', textAlign: TextAlign.center),
                  ),
                )
              : _courant >= items.length
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_rounded,
                                size: 56, color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            Text('$_score / ${items.length}', style: theme.textTheme.displaySmall),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Terminer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: padPage(context, v: 16),
                      children: [
                        LinearProgressIndicator(value: _courant / items.length),
                        const SizedBox(height: 8),
                        Text('Question ${_courant + 1} sur ${items.length} · score $_score',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        Text('Écoutez, puis écrivez ce que vous entendez.',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Center(
                          child: FilledButton.tonalIcon(
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('Écouter'),
                            onPressed: _ecouter,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controleur,
                          enabled: !_verifie,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Votre réponse',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _verifie ? null : _verifier(),
                        ),
                        const SizedBox(height: 12),
                        if (!_verifie)
                          FilledButton(onPressed: _verifier, child: const Text('Vérifier'))
                        else ...[
                          Text(
                            _juste ? 'Bonne réponse !' : 'Ce n\'était pas ça : « ${items[_courant]} ».',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _suivant,
                            child: Text(_courant + 1 >= items.length ? 'Voir le score' : 'Suivant'),
                          ),
                        ],
                      ],
                    ),
    );
  }
}
