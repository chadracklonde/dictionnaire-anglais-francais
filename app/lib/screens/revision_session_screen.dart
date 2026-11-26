import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/speech.dart';
import '../widgets/mise_en_page.dart';

/// Une séance de cartes : le mot s'affiche, on essaie de se rappeler, puis on vérifie.
class RevisionSessionScreen extends StatefulWidget {
  const RevisionSessionScreen({super.key, required this.cles});

  /// Mots à réviser, les plus en retard d'abord.
  final List<String> cles;

  @override
  State<RevisionSessionScreen> createState() => _RevisionSessionScreenState();
}

class _RevisionSessionScreenState extends State<RevisionSessionScreen> {
  static const int _parSeance = 20;

  late final List<String> _file;
  final Set<String> _reposees = {};
  int _total = 0;
  int _faits = 0;
  int _reussis = 0;
  Fiche? _fiche;
  bool _reponse = false;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _file = widget.cles.take(_parSeance).toList();
    _total = _file.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final services = AppScope.of(context);
    while (_file.isNotEmpty) {
      final mot = await services.resoudre(_file.first);
      if (mot == null) {
        // Le mot n'est plus dans la base : on l'écarte.
        _file.removeAt(0);
        _total--;
        continue;
      }
      final fiche = await services.moteur.fiche(mot);
      if (!mounted) return;
      setState(() {
        _fiche = fiche;
        _reponse = false;
        _chargement = false;
      });
      return;
    }
    if (mounted) {
      setState(() {
        _fiche = null;
        _chargement = false;
      });
    }
  }

  Future<void> _repondre(bool connu) async {
    final user = AppScope.of(context).user;
    final cle = _file.removeAt(0);
    await user.repondre(cle, connu);
    if (connu) {
      _faits++;
      if (!_reposees.contains(cle)) _reussis++;
    } else if (_reposees.add(cle)) {
      _file.add(cle); // une seconde chance en fin de séance
    } else {
      _faits++;
    }
    if (!mounted) return;
    setState(() => _chargement = true);
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fiche = _fiche;
    return Scaffold(
      appBar: AppBar(title: Text(fiche == null ? 'Révision' : 'Révision · $_faits / $_total')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : fiche == null
              ? _Fin(reussis: _reussis, total: _total)
              : ListView(
                  padding: padPage(context, v: 16),
                  children: [
                    LinearProgressIndicator(value: _total == 0 ? 1 : _faits / _total),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(fiche.mot.mot,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(natureFr(fiche.mot.nature),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.secondary, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Center(
                      child: IconButton(
                        tooltip: 'Écouter',
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () => speech.speak(fiche.mot.mot,
                            accent: AppScope.of(context).user.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_reponse)
                      FilledButton(
                        onPressed: () => setState(() => _reponse = true),
                        child: const Text('Voir la réponse'),
                      )
                    else
                      _Reponse(fiche: fiche, surReponse: _repondre),
                  ],
                ),
    );
  }
}

class _Reponse extends StatelessWidget {
  const _Reponse({required this.fiche, required this.surReponse});

  final Fiche fiche;
  final void Function(bool connu) surReponse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exemples = [
      for (final s in fiche.sens)
        if (s.exemple.isNotEmpty) s.exemple
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fiche.equivalents.isEmpty)
          const Text('Pas d\'équivalent français enregistré.')
        else
          for (final e in fiche.equivalents.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                e.genre.isEmpty ? e.fr : '${e.fr} (${genreFr(e.genre)})',
                style: theme.textTheme.titleLarge,
              ),
            ),
        if (exemples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('« ${exemples.first} »',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => surReponse(false),
                child: const Text('Je ne savais pas'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => surReponse(true),
                child: const Text('Je savais'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fin extends StatelessWidget {
  const _Fin({required this.reussis, required this.total});

  final int reussis;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Séance terminée', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'Aucun mot à réviser.'
                  : '$reussis mot(s) sus du premier coup sur $total.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Terminer'),
            ),
          ],
        ),
      ),
    );
  }
}
