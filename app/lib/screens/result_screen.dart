import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/user_store.dart';
import '../widgets/fiche_card.dart';
import 'entry_screen.dart';

/// Résultat d'une recherche : un onglet anglais → français, un onglet français → anglais.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.requete});

  final String requete;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Future<Resultat>? _resultat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resultat ??= _charger();
  }

  Future<Resultat> _charger() async {
    final services = AppScope.of(context);
    final r = await services.moteur.chercher(widget.requete);
    if (r.fiches.isNotEmpty) {
      final m = r.fiches.first.mot;
      services.user.ajouterHistorique(UserStore.cle(m.mot, m.nature));
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Resultat>(
      future: _resultat,
      builder: (context, snap) {
        final r = snap.data;
        return Scaffold(
          appBar: AppBar(title: Text(widget.requete)),
          body: snap.hasError
              ? Center(child: Text('Erreur : ${snap.error}'))
              : r == null
                  ? const Center(child: CircularProgressIndicator())
                  : r.vide
                      ? _Vide(resultat: r)
                      : _Onglets(resultat: r),
        );
      },
    );
  }
}

class _Onglets extends StatelessWidget {
  const _Onglets({required this.resultat});

  final Resultat resultat;

  @override
  Widget build(BuildContext context) {
    final r = resultat;
    final nbEn = r.fiches.length + (r.contraction == null ? 0 : 1);
    final debut = r.directionParDefaut == Direction.anglaisFrancais ? 0 : 1;
    return DefaultTabController(
      length: 2,
      initialIndex: debut,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(text: 'Anglais → français ($nbEn)'),
                Tab(text: 'Français → anglais (${r.inverses.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ListeAnglais(resultat: r),
                _ListeFrancais(resultat: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        texte,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ListeAnglais extends StatelessWidget {
  const _ListeAnglais({required this.resultat});

  final Resultat resultat;

  @override
  Widget build(BuildContext context) {
    final r = resultat;
    if (r.fiches.isEmpty && r.contraction == null) {
      return const Center(child: Text('Aucun mot anglais trouvé.'));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (r.regleAnglais != null) _Note(r.regleAnglais!),
        if (r.contraction != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.contraction!.forme,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('contraction de « ${r.contraction!.developpe} »',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(r.contraction!.traduction, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ),
        for (final f in r.fiches) FicheCard(fiche: f),
      ],
    );
  }
}

class _ListeFrancais extends StatelessWidget {
  const _ListeFrancais({required this.resultat});

  final Resultat resultat;

  @override
  Widget build(BuildContext context) {
    final r = resultat;
    if (r.inverses.isEmpty) {
      return const Center(child: Text('Aucun mot français trouvé.'));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (r.regleFrancais != null) _Note(r.regleFrancais!),
        for (final e in r.inverses)
          ListTile(
            title: Text(e.mot.mot, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${natureFr(e.mot.nature)} · ${e.equivalents.map((x) => x.fr).take(3).join(', ')}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: e.confirme
                ? Icon(Icons.verified_rounded, color: theme.colorScheme.secondary, semanticLabel: 'Confirmé')
                : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => EntryScreen(mot: e.mot)),
            ),
          ),
      ],
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.resultat});

  final Resultat resultat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Aucun résultat pour « ${resultat.requete} ».', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (resultat.suggestions.isNotEmpty) ...[
          const Text('Essayez plutôt :'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in resultat.suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => ResultScreen(requete: s)),
                  ),
                ),
            ],
          ),
        ] else
          const Text('Vérifiez l\'orthographe ou essayez une autre forme du mot.'),
      ],
    );
  }
}
