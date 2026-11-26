import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../widgets/mise_en_page.dart';
import 'entry_screen.dart';

/// Retrouver un mot à partir de ce qu'il veut dire : cherche dans les définitions.
class DefinitionScreen extends StatefulWidget {
  const DefinitionScreen({super.key, this.texteInitial = ''});

  final String texteInitial;

  @override
  State<DefinitionScreen> createState() => _DefinitionScreenState();
}

class _DefinitionScreenState extends State<DefinitionScreen> {
  late final TextEditingController _controleur;
  Future<List<ParDefinition>>? _resultats;

  @override
  void initState() {
    super.initState();
    _controleur = TextEditingController(text: widget.texteInitial);
    if (widget.texteInitial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chercher());
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _chercher() {
    final texte = _controleur.text.trim();
    if (texte.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _resultats = AppScope.of(context).moteur.chercherParDefinition(texte));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chercher par définition')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _controleur,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Par exemple : animal domestique, to leave a place',
                prefixIcon: const Icon(Icons.manage_search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Chercher',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _chercher,
                ),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
              ),
              onSubmitted: (_) => _chercher(),
            ),
          ),
          Expanded(
            child: _resultats == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Décrivez le mot en quelques mots, en français ou en anglais. '
                        'Les mots dont la définition contient tous vos mots sont proposés.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : FutureBuilder<List<ParDefinition>>(
                    future: _resultats,
                    builder: (context, snap) {
                      if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
                      final liste = snap.data;
                      if (liste == null) return const Center(child: CircularProgressIndicator());
                      if (liste.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aucune définition ne contient tous ces mots. Essayez-en moins, '
                              'ou des mots plus simples (au moins trois lettres).',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView(
                        padding: padPage(context, v: 8),
                        children: [
                          for (final r in liste)
                            ListTile(
                              title: Text(r.mot.mot,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${natureFr(r.mot.nature)} · ${r.extrait}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: r.mot)),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
