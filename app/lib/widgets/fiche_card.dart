import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/libelles.dart';
import '../data/speech.dart';
import '../data/user_store.dart';
import '../screens/conjugation_screen.dart';

/// Fiche d'un mot anglais : équivalents français en avant, définitions anglaises repliables.
class FicheCard extends StatefulWidget {
  const FicheCard({super.key, required this.fiche});

  final Fiche fiche;

  @override
  State<FicheCard> createState() => _FicheCardState();
}

class _FicheCardState extends State<FicheCard> {
  static const int _equivalentsVisibles = 8;
  bool _tousLesEquivalents = false;
  bool _definitions = false;

  Future<void> _lire(BuildContext context) async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await speech.speak(widget.fiche.mot.mot, accent: services.user.accent);
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Aucune voix anglaise n\'est installée sur cet appareil.'),
      ));
    }
  }

  String _api(String accent) {
    final liste = widget.fiche.prononciations.where((p) => p.accent == accent);
    return liste.isEmpty ? '' : liste.first.api;
  }

  @override
  Widget build(BuildContext context) {
    final fiche = widget.fiche;
    final theme = Theme.of(context);
    final services = AppScope.of(context);
    final cle = UserStore.cle(fiche.mot.mot, fiche.mot.nature);
    final favori = services.user.estFavori(cle);
    final us = _api('us');
    final uk = _api('uk');

    final equivalents = fiche.equivalents;
    final visibles = _tousLesEquivalents || equivalents.length <= _equivalentsVisibles
        ? equivalents
        : equivalents.take(_equivalentsVisibles).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: fiche.mot.mot,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ${natureFr(fiche.mot.nature)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ]),
                  ),
                  ),
                ),
                IconButton(
                  tooltip: 'Écouter',
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () => _lire(context),
                ),
                IconButton(
                  tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  icon: Icon(favori ? Icons.star_rounded : Icons.star_border_rounded),
                  onPressed: () => services.user.basculerFavori(cle),
                ),
              ],
            ),
            if (fiche.formeDemandee != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '« ${fiche.formeDemandee} » est une forme de ${fiche.mot.mot}'
                  '${fiche.etiquetteRenvoi.isEmpty ? '' : ' (${baliseFr(fiche.etiquetteRenvoi)})'}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (us.isNotEmpty || uk.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  [if (us.isNotEmpty) 'US $us', if (uk.isNotEmpty) 'UK $uk'].join('   '),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 6),
            if (equivalents.isEmpty)
              Text(
                'Pas d\'équivalent français enregistré.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else ...[
              for (final e in visibles) _LigneEquivalent(equivalent: e),
              if (equivalents.length > _equivalentsVisibles)
                TextButton(
                  onPressed: () => setState(() => _tousLesEquivalents = !_tousLesEquivalents),
                  child: Text(_tousLesEquivalents
                      ? 'Voir moins'
                      : 'Voir les ${equivalents.length} équivalents'),
                ),
            ],
            if (fiche.definitionsFr.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Définitions', style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              for (final d in fiche.definitionsFr.take(4))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $d', style: theme.textTheme.bodyMedium),
                ),
            ],
            if (fiche.sens.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState(() => _definitions = !_definitions),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(_definitions ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Définitions en anglais (${fiche.sens.length})',
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (_definitions)
                for (final s in fiche.sens) _LigneSens(sens: s),
            ],
            if (fiche.formes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Formes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                fiche.formes.take(12).map((f) {
                  final b = baliseFr(f.etiquettes);
                  return b.isEmpty ? f.forme : '${f.forme} ($b)';
                }).join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (fiche.mot.nature == 'verb') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Conjuguer'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ConjugationScreen(verbeInitial: fiche.mot.mot),
                  )),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LigneEquivalent extends StatelessWidget {
  const _LigneEquivalent({required this.equivalent});

  final Equivalent equivalent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genre = genreFr(equivalent.genre);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(TextSpan(children: [
        TextSpan(
          text: equivalent.fr,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (genre.isNotEmpty)
          TextSpan(
            text: '  $genre',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        if (equivalent.etiquette.isNotEmpty)
          TextSpan(
            text: '  (${equivalent.etiquette})',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ])),
    );
  }
}

class _LigneSens extends StatelessWidget {
  const _LigneSens({required this.sens});

  final Sens sens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balises = baliseFr(sens.etiquettes);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '${sens.ordre}. '),
            if (balises.isNotEmpty)
              TextSpan(
                text: '[$balises] ',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            TextSpan(text: sens.definition),
          ])),
          if (sens.exemple.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                sens.exemple,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
