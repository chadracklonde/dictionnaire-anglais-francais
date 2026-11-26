import 'package:dicoenfr_engine/dicoenfr_engine.dart' show numeroDeJour;
import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/mise_en_page.dart';

/// Progression : série de jours, réponses des deux dernières semaines, mots maîtrisés.
class StatistiquesScreen extends StatelessWidget {
  const StatistiquesScreen({super.key});

  static const List<String> _initiales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ma progression')),
      body: ListenableBuilder(
        listenable: user,
        builder: (context, _) {
          final cartes = user.revisions.values;
          final vus = cartes.where((c) => c.vus > 0).length;
          final maitrises = cartes.where((c) => c.maitrisee).length;
          final reponses = cartes.fold<int>(0, (t, c) => t + c.vus);
          final justes = cartes.fold<int>(0, (t, c) => t + c.justes);
          final taux = reponses == 0 ? null : (100 * justes / reponses).round();
          final difficiles = user.difficiles(user.revisions.keys).length;
          final aujourdhui = numeroDeJour(DateTime.now());
          final jours = [for (var i = 13; i >= 0; i--) aujourdhui - i];
          final valeurs = [for (final j in jours) user.activite[j]?[0] ?? 0];
          final maxi = valeurs.fold<int>(user.objectifJour, (m, v) => v > m ? v : m);
          return ListView(
            padding: padPage(context),
            children: [
              Row(
                children: [
                  Expanded(child: _Chiffre(valeur: '${user.serie}', libelle: 'jour(s) de suite')),
                  Expanded(child: _Chiffre(valeur: '${user.meilleureSerieJours}', libelle: 'meilleure série')),
                  Expanded(child: _Chiffre(valeur: '${user.activite.length}', libelle: 'jour(s) de révision')),
                ],
              ),
              const SizedBox(height: 24),
              Text('Réponses des 14 derniers jours', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Objectif : ${user.objectifJour} par jour', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < jours.length; i++)
                      Expanded(
                        child: Semantics(
                          label: '${valeurs[i]} réponse(s)'
                              '${i == jours.length - 1 ? ', aujourd\'hui' : ''}',
                          excludeSemantics: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(valeurs[i] == 0 ? '' : '${valeurs[i]}',
                                    style: theme.textTheme.labelSmall),
                                Container(
                                  height: valeurs[i] == 0 ? 3 : 4 + 70 * valeurs[i] / maxi,
                                  decoration: BoxDecoration(
                                    color: valeurs[i] >= user.objectifJour
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _initiales[DateTime.fromMillisecondsSinceEpoch(
                                              jours[i] * Duration.millisecondsPerDay,
                                              isUtc: true)
                                          .weekday -
                                      1],
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: i == jours.length - 1 ? FontWeight.w700 : null),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('Barre rouge : objectif atteint.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              Text('Mes mots', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _Ligne('Mots révisés au moins une fois', '$vus'),
              _Ligne('Mots maîtrisés', '$maitrises'),
              _Ligne('Mots difficiles', '$difficiles'),
              _Ligne('Réponses données', '$reponses'),
              _Ligne('Bonnes réponses', taux == null ? '—' : '$taux %'),
            ],
          );
        },
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.valeur, required this.libelle});

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(valeur,
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
        Text(libelle, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur);

  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(libelle)),
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
