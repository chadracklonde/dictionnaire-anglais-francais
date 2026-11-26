import 'package:flutter/material.dart';

import '../app.dart';
import '../data/user_store.dart';
import '../widgets/mise_en_page.dart';
import 'quiz_screen.dart';
import 'revision_session_screen.dart';
import 'statistiques_screen.dart';
import 'themes_screen.dart';

/// Onglet « Réviser » : cartes à répétition espacée, quiz et listes thématiques.
class ReviserScreen extends StatefulWidget {
  const ReviserScreen({super.key});

  @override
  State<ReviserScreen> createState() => _ReviserScreenState();
}

class _ReviserScreenState extends State<ReviserScreen> {
  static const String _tout = '*';
  static const String _favoris = '★';

  String _portee = _tout;

  List<String> _cles(UserStore user) {
    if (_portee == _favoris) return List.of(user.favoris);
    if (_portee == _tout || !user.listes.containsKey(_portee)) return user.motsARevoir();
    return List.of(user.listes[_portee]!);
  }

  void _ouvrir(Widget ecran) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: user,
      builder: (context, _) {
        final cles = _cles(user);
        final dues = user.aReviser(cles);
        final maitrisees = cles.where((c) => user.carteDe(c).maitrisee).length;
        final difficiles = user.difficiles(cles);
        final objectif = user.objectifJour;
        final faites = user.reponsesAujourdhui;
        return Scaffold(
          appBar: AppBar(title: const Text('Réviser')),
          body: ListView(
            padding: padPage(context),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _ouvrir(const StatistiquesScreen()),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: objectif == 0 ? 1 : (faites / objectif).clamp(0.0, 1.0),
                                strokeWidth: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                              Text('$faites', style: theme.textTheme.titleMedium),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faites >= objectif
                                    ? 'Objectif du jour atteint'
                                    : 'Aujourd\'hui : $faites / $objectif réponses',
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                user.serie == 0
                                    ? 'Révisez pour commencer une série.'
                                    : 'Série : ${user.serie} jour(s) de suite',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Quels mots ?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Tous mes mots'),
                    selected: _portee == _tout,
                    onSelected: (_) => setState(() => _portee = _tout),
                  ),
                  ChoiceChip(
                    label: Text('Favoris (${user.favoris.length})'),
                    selected: _portee == _favoris,
                    onSelected: (_) => setState(() => _portee = _favoris),
                  ),
                  for (final nom in user.listes.keys)
                    ChoiceChip(
                      label: Text('$nom (${user.listes[nom]!.length})'),
                      selected: _portee == nom,
                      onSelected: (_) => setState(() => _portee = nom),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (cles.isEmpty)
                Text(
                  'Ajoutez des mots à vos favoris ou à une liste (bouton « Listes » d\'une fiche), '
                  'ou prenez une liste de vocabulaire prête à l\'emploi.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else ...[
                Text('${cles.length} mot(s) · ${dues.length} à réviser aujourd\'hui · '
                    '$maitrisees maîtrisé(s)',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Un mot su revient de plus en plus tard ; un mot oublié revient tout de suite.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.style_rounded),
                  label: Text(dues.isEmpty
                      ? 'Rien à réviser aujourd\'hui'
                      : 'Réviser (${dues.length > 20 ? 20 : dues.length})'),
                  onPressed: dues.isEmpty
                      ? null
                      : () => _ouvrir(RevisionSessionScreen(cles: dues)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.quiz_rounded),
                  label: const Text('Quiz : anglais → français'),
                  onPressed: () => _ouvrir(QuizScreen(cles: cles)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.translate_rounded),
                  label: const Text('Quiz : français → anglais'),
                  onPressed: () =>
                      _ouvrir(QuizScreen(cles: cles, mode: ModeQuiz.francaisAnglais)),
                ),
                if (difficiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.priority_high_rounded),
                    label: Text('Mots difficiles (${difficiles.length})'),
                    onPressed: () => _ouvrir(RevisionSessionScreen(cles: difficiles)),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Quiz des faux amis'),
                onPressed: () => _ouvrir(const QuizScreen(mode: ModeQuiz.fauxAmis)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.format_quote_rounded),
                label: const Text('Quiz des expressions'),
                onPressed: () => _ouvrir(const QuizScreen(mode: ModeQuiz.expressions)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('Listes de vocabulaire (voyage, cuisine…)'),
                onPressed: () => _ouvrir(const ThemesScreen()),
              ),
            ],
          ),
        );
      },
    );
  }
}
