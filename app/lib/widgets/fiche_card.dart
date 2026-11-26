import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/audio_index.dart';
import '../data/audio_lecture.dart';
import '../data/libelles.dart';
import '../data/speech.dart';
import '../data/user_store.dart';
import '../screens/conjugation_screen.dart';
import '../screens/expressions_screen.dart';
import '../screens/result_screen.dart';
import 'listes.dart';

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
  EntreeAudio? _credit;

  Future<void> _lire(BuildContext context) async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (services.user.accent == 'us') {
      // Les enregistrements sont américains ; pour l'accent britannique, la voix du téléphone.
      final entree = await LectureAudio.lire(widget.fiche);
      if (mounted) setState(() => _credit = entree);
      if (entree != null) return;
    } else if (_credit != null) {
      setState(() => _credit = null);
    }
    final ok = await speech.speak(widget.fiche.mot.mot, accent: services.user.accent);
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Aucune voix anglaise n\'est installée sur cet appareil.'),
      ));
    }
  }

  Future<void> _basculerFavori(BuildContext context, String cle) async {
    final user = AppScope.of(context).user;
    final messenger = ScaffoldMessenger.of(context);
    final position = user.favoris.indexOf(cle);
    final retire = position >= 0;
    await user.basculerFavori(cle);
    if (!retire) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Retiré des favoris.'),
        action: SnackBarAction(label: 'Annuler', onPressed: () => user.insererFavori(position, cle)),
      ));
  }

  Future<void> _modifierNote(BuildContext context, String cle) async {
    final user = AppScope.of(context).user;
    final texte = await demanderTexte(
      context,
      titre: 'Ma note sur « ${widget.fiche.mot.mot} »',
      initial: user.noteDe(cle),
      indication: 'Un exemple, une astuce pour retenir…',
      lignes: 3,
      max: 2000,
    );
    if (texte != null) await user.definirNote(cle, texte);
  }

  void _partager() {
    final fiche = widget.fiche;
    final eq = fiche.equivalents.take(6).map((e) => e.fr).join(', ');
    final texte = '${fiche.mot.mot} (${natureFr(fiche.mot.nature)})'
        '${eq.isEmpty ? '' : ' : $eq'}\n— Anglais Français';
    Share.share(texte);
  }

  Future<void> _signaler() async {
    final mot = widget.fiche.mot;
    final url = Uri.https('github.com', '/chadracklonde/dictionnaire-anglais-francais/issues/new', {
      'title': 'Erreur dans la fiche « ${mot.mot} » (${natureFr(mot.nature)})',
      'body': 'Mot : ${mot.mot}\nNature : ${mot.nature}\n\nCe qui est faux ou manque :\n',
    });
    await launchUrl(url, mode: LaunchMode.externalApplication);
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
    final us = _api('us');
    final uk = _api('uk');

    final equivalents = fiche.equivalents;
    // Les exemples courts d'abord : un exemple de trois lignes écrase la fiche.
    final exemples = ([
      for (final x in fiche.sens)
        if (x.exemple.isNotEmpty && x.exemple.length <= 140) x.exemple
    ]..sort((a, b) => a.length.compareTo(b.length)))
        .take(2)
        .toList();
    // Formes : sans doublon, sans les formes vieillies ou régionales.
    final vuesFormes = <String>{};
    final formes = [
      for (final f in fiche.formes)
        if (!RegExp(r'archaic|obsolete|dialect|rare|nonstandard|informal|misspelling')
                .hasMatch(f.etiquettes) &&
            vuesFormes.add(f.forme.toLowerCase()))
          f
    ];
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
                  tooltip: 'Partager',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _partager,
                ),
                ListenableBuilder(
                  listenable: services.user,
                  builder: (context, _) {
                    final actif = services.user.estFavori(cle);
                    return IconButton(
                      tooltip: actif ? 'Retirer des favoris' : 'Ajouter aux favoris',
                      icon: Icon(actif ? Icons.star_rounded : Icons.star_border_rounded),
                      onPressed: () => _basculerFavori(context, cle),
                    );
                  },
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
            if (fiche.fauxAmi != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Semantics(
                  container: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Faux ami : « ${fiche.mot.mot} » ne veut pas dire « ${fiche.fauxAmi!.piege} ». '
                          'Il signifie : ${fiche.fauxAmi!.vrai}.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (fiche.expression != null) _BlocExpression(info: fiche.expression!),
            if (us.isNotEmpty || uk.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  [if (us.isNotEmpty) 'US $us', if (uk.isNotEmpty) 'UK $uk'].join('   '),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (_credit != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () {
                    final url = _credit!.licenceUrl.isNotEmpty ? _credit!.licenceUrl : _credit!.page;
                    if (url.startsWith('https://')) {
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    _credit!.credit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.underline,
                    ),
                  ),
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
            if (exemples.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Exemples', style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              for (final e in exemples)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('« $e »',
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
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
            if (formes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Formes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                formes.take(12).map((f) {
                  final b = baliseFr(f.etiquettes);
                  return b.isEmpty ? f.forme : '${f.forme} ($b)';
                }).join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            _MotsLies(titre: 'Synonymes', mots: fiche.synonymes),
            _MotsLies(titre: 'Contraires', mots: fiche.contraires),
            _MotsLies(titre: 'Verbes à particule', mots: fiche.particules),
            _MotsLies(titre: 'Même famille', mots: fiche.famille),
            if (fiche.expressionsAvec.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Expressions avec « ${fiche.mot.mot} »', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final e in fiche.expressionsAvec.take(6)) CarteExpression(ligne: e),
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
            ListenableBuilder(
              listenable: services.user,
              builder: (context, _) {
                final note = services.user.noteDe(cle);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Ma note', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(note, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                          label: Text(note.isEmpty ? 'Ajouter une note' : 'Modifier la note'),
                          onPressed: () => _modifierNote(context, cle),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.playlist_add_rounded, size: 20),
                          label: const Text('Listes'),
                          onPressed: () => afficherChoixListes(context, cle),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Signaler une erreur'),
                          onPressed: _signaler,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Ce qu'on sait d'une expression : type, niveau de langue, sens littéral, équivalent recommandé, exemple.
class _BlocExpression extends StatelessWidget {
  const _BlocExpression({required this.info});

  final InfoExpression info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registre = registreFr(info.registre);
    final theme2 = themesExpression[info.theme];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              typeExpressionUnFr(info.type)[0].toUpperCase() + typeExpressionUnFr(info.type).substring(1),
              if (registre.isNotEmpty) registre,
              if (theme2 != null) theme2.toLowerCase(),
            ].join(' · '),
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface),
          ),
          if (info.fr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Équivalent recommandé : ${info.fr}',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
          ],
          if (info.litteral.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Mot à mot : ${info.litteral}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
          ],
          if (info.exemple.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Exemple : ${info.exemple}',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

/// Une rangée de mots liés ; un appui lance la recherche du mot.
class _MotsLies extends StatelessWidget {
  const _MotsLies({required this.titre, required this.mots});

  final String titre;
  final List<String> mots;

  @override
  Widget build(BuildContext context) {
    if (mots.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final m in mots)
                ActionChip(
                  label: Text(m),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ResultScreen(requete: m)),
                  ),
                ),
            ],
          ),
        ],
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
