import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../widgets/mise_en_page.dart';

/// Conjugaison anglaise : saisie d'un verbe (à l'infinitif ou conjugué), trois formes.
class ConjugationScreen extends StatefulWidget {
  const ConjugationScreen({super.key, this.verbeInitial});

  final String? verbeInitial;

  @override
  State<ConjugationScreen> createState() => _ConjugationScreenState();
}

class _ConjugationScreenState extends State<ConjugationScreen> {
  final _controleur = TextEditingController();
  Polarite _polarite = Polarite.affirmative;
  Mot? _mot;
  String _verbe = '';
  Conjugaison? _resultat;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final v = widget.verbeInitial;
    if (v != null) {
      _controleur.text = v;
      WidgetsBinding.instance.addPostFrameCallback((_) => _conjuguer(v));
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _conjuguer(String texte) async {
    final t = texte.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    final moteur = AppScope.of(context).moteur;
    setState(() => _enCours = true);
    final r = await moteur.chercher(t);
    final verbes = r.fiches.where((f) => f.mot.nature == 'verb').toList();
    Mot? mot;
    if (verbes.isNotEmpty) mot = verbes.first.mot;
    final conj = mot != null
        ? await moteur.conjuguerMot(mot, polarite: _polarite)
        : conjuguer(t.toLowerCase(), polarite: _polarite);
    if (!mounted) return;
    setState(() {
      _mot = mot;
      _verbe = mot?.mot ?? t.toLowerCase();
      _resultat = conj;
      _enCours = false;
    });
  }

  Future<void> _changerPolarite(Polarite p) async {
    setState(() => _polarite = p);
    if (_verbe.isEmpty) return;
    final moteur = AppScope.of(context).moteur;
    final conj = _mot != null
        ? await moteur.conjuguerMot(_mot!, polarite: p)
        : conjuguer(_verbe, polarite: p);
    if (!mounted) return;
    setState(() => _resultat = conj);
  }

  String _texteComplet(Conjugaison c) {
    final b = StringBuffer('${c.infinitif}\n');
    for (final g in c.groupes) {
      b.writeln('\n${g.titre}');
      for (final t in g.temps) {
        b.writeln('\n${t.titre}');
        for (final l in t.lignes) {
          b.writeln(l.sujet.isEmpty ? l.texte : '${l.sujet} ${l.texte}');
        }
      }
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _resultat;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conjugaison'),
        actions: [
          if (c != null)
            IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: _texteComplet(c)));
                messenger.showSnackBar(const SnackBar(content: Text('Conjugaison copiée.')));
              },
            ),
        ],
      ),
      body: ListView(
        padding: padPage(context),
        children: [
          TextField(
            controller: _controleur,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Un verbe anglais (go, went, to be…)',
              prefixIcon: Icon(Icons.menu_book_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
            ),
            onSubmitted: _conjuguer,
          ),
          const SizedBox(height: 12),
          SegmentedButton<Polarite>(
            segments: const [
              ButtonSegment(value: Polarite.affirmative, label: Text('Affirmative')),
              ButtonSegment(value: Polarite.negative, label: Text('Négative')),
              ButtonSegment(value: Polarite.interrogative, label: Text('Question')),
            ],
            selected: {_polarite},
            onSelectionChanged: (s) => _changerPolarite(s.first),
          ),
          const SizedBox(height: 16),
          if (_enCours) const Center(child: CircularProgressIndicator()),
          if (c == null && !_enCours)
            Text(
              'Saisissez un verbe : toutes les formes (went, gone…) mènent à son infinitif.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (c != null && !_enCours) ...[
            Text(c.infinitif, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            for (final n in c.notes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(n,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            for (final g in c.groupes) ...[
              const SizedBox(height: 16),
              Text(g.titre, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              for (final t in g.temps)
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.titre, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        for (final l in t.lignes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(l.sujet.isEmpty ? l.texte : '${l.sujet} ${l.texte}'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
