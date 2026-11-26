import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/mise_en_page.dart';

/// Sorte de quiz : le mot anglais à traduire, le mot français à retrouver en anglais, ou les faux amis.
enum ModeQuiz { anglaisFrancais, francaisAnglais, fauxAmis, expressions, trous }

class _Question {
  const _Question(this.cle, this.intitule, this.bonne, this.options, [this.explication = '']);

  /// Mot révisé (clé « mot<TAB>nature »), ou null pour un faux ami : la progression n'en tient pas compte.
  final String? cle;
  final String intitule;
  final String bonne;
  final List<String> options;
  final String explication;
}

/// Quiz de dix questions : un mot anglais, quatre propositions françaises.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.cles = const [], this.mode = ModeQuiz.anglaisFrancais});

  final List<String> cles;
  final ModeQuiz mode;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const int _nombre = 10;

  List<_Question>? _questions;
  int _courante = 0;
  int _score = 0;
  String? _choix;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparer());
  }

  Future<void> _preparer() async {
    final services = AppScope.of(context);
    final questions = switch (widget.mode) {
      ModeQuiz.fauxAmis => await _questionsFauxAmis(services),
      ModeQuiz.expressions => await _questionsExpressions(services),
      ModeQuiz.trous => await _questionsTrous(services),
      _ => await _questionsMots(services),
    };
    if (!mounted) return;
    setState(() => _questions = questions);
  }

  Future<List<_Question>> _questionsFauxAmis(AppServices services) async {
    List<FauxAmi> faux;
    try {
      faux = await services.source.fauxAmisHasard(_nombre + 2);
    } catch (_) {
      faux = const [];
    }
    if (faux.length < 3) return const [];
    final questions = <_Question>[];
    for (var i = 0; i < faux.length && questions.length < _nombre; i++) {
      final f = faux[i];
      final autres = [
        for (var k = 1; k < faux.length; k++) faux[(i + k) % faux.length].vrai,
      ];
      final options = <String>{f.vrai, f.piege};
      for (final a in autres) {
        if (options.length < 4) options.add(a);
      }
      questions.add(_Question(
        null,
        'Que veut dire « ${f.mot} » ?',
        f.vrai,
        options.toList()..shuffle(),
        'Piège : « ${f.mot} » ne veut pas dire « ${f.piege} ».',
      ));
    }
    return questions;
  }

  Future<List<_Question>> _questionsExpressions(AppServices services) async {
    List<LigneExpression> expressions;
    try {
      expressions = await services.source.expressionsCureesHasard(_nombre + 6);
    } catch (_) {
      expressions = const [];
    }
    expressions = [for (final e in expressions) if (e.fr.isNotEmpty) e];
    if (expressions.length < 4) return const [];
    final questions = <_Question>[];
    for (var i = 0; i < expressions.length && questions.length < _nombre; i++) {
      final e = expressions[i];
      final bonne = e.fr;
      final options = <String>{bonne};
      for (var k = 1; k < expressions.length && options.length < 4; k++) {
        options.add(expressions[(i + k) % expressions.length].fr);
      }
      if (options.length < 3) continue;
      questions.add(_Question(
        null,
        'Que veut dire « ${e.mot.mot} » ?',
        bonne,
        options.toList()..shuffle(),
        e.litteral.isEmpty ? '' : 'Mot à mot : ${e.litteral}.',
      ));
    }
    return questions;
  }

  /// Phrases d'exemple dont on a retiré un mot courant : on choisit le bon parmi quatre.
  Future<List<_Question>> _questionsTrous(AppServices services) async {
    List<String> candidats;
    try {
      candidats = await services.source.motsHasard(40);
    } catch (_) {
      return const [];
    }
    if (candidats.length < 8) return const [];
    final questions = <_Question>[];
    for (final mot in candidats) {
      if (questions.length >= _nombre) break;
      if (mot.length < 3) continue;
      final trouves = await services.source.motsParRecherche(plier(mot));
      if (trouves.isEmpty) continue;
      final fiche = await services.moteur.fiche(trouves.first);
      final motif = RegExp('\\b${RegExp.escape(mot)}\\b', caseSensitive: false);
      String? phrase;
      for (final s in fiche.sens) {
        if (s.exemple.length <= 90 && motif.hasMatch(s.exemple)) {
          phrase = s.exemple;
          break;
        }
      }
      if (phrase == null) continue;
      final autres = [for (final c in candidats) if (c.toLowerCase() != mot.toLowerCase()) c]..shuffle();
      final options = <String>[mot.toLowerCase(), ...autres.take(3).map((c) => c.toLowerCase())];
      final equivalent = fiche.equivalents.isEmpty ? '' : fiche.equivalents.first.fr;
      questions.add(_Question(
        null,
        'Complétez : « ${phrase.replaceFirst(motif, '_____')} »',
        mot.toLowerCase(),
        options.toSet().toList()..shuffle(),
        '« $phrase »${equivalent.isEmpty ? '' : ' — $mot : $equivalent'}',
      ));
    }
    return questions;
  }

  Future<List<_Question>> _questionsMots(AppServices services) async {
    final inverse = widget.mode == ModeQuiz.francaisAnglais;
    // D'abord les mots à réviser, puis les autres dans le désordre.
    final dues = services.user.aReviser(widget.cles);
    final autres = widget.cles.where((c) => !dues.contains(c)).toList()..shuffle();
    final ordre = [...dues, ...autres];
    final questions = <_Question>[];
    for (final cle in ordre) {
      if (questions.length >= _nombre) break;
      final mot = await services.resoudre(cle);
      if (mot == null) continue;
      final fiche = await services.moteur.fiche(mot);
      if (fiche.equivalents.isEmpty) continue;
      final francais = fiche.equivalents.first.fr;
      final bonne = inverse ? mot.mot : francais;
      final connus = inverse
          ? {mot.mot.toLowerCase()}
          : {for (final e in fiche.equivalents) e.fr.toLowerCase()};
      List<String> hasard;
      try {
        hasard = inverse
            ? await services.source.motsHasard(12)
            : await services.source.equivalentsHasard(12);
      } catch (_) {
        hasard = const [];
      }
      final mauvaises = <String>[];
      for (final h in hasard) {
        if (mauvaises.length < 3 && !connus.contains(h.toLowerCase()) && !mauvaises.contains(h)) {
          mauvaises.add(h);
        }
      }
      if (mauvaises.isEmpty) continue;
      questions.add(_Question(
        cle,
        inverse ? 'Comment dit-on « $francais » en anglais ?' : 'Que veut dire « ${mot.mot} » ?',
        bonne,
        [bonne, ...mauvaises]..shuffle(),
      ));
    }
    return questions;
  }

  Future<void> _repondre(String option) async {
    final q = _questions![_courante];
    final juste = option == q.bonne;
    setState(() {
      _choix = option;
      if (juste) _score++;
    });
    final cle = q.cle;
    if (cle != null) await AppScope.of(context).user.repondre(cle, juste);
  }

  void _suivante() => setState(() {
        _courante++;
        _choix = null;
      });

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.mode) {
          ModeQuiz.anglaisFrancais => 'Quiz',
          ModeQuiz.francaisAnglais => 'Quiz français → anglais',
          ModeQuiz.fauxAmis => 'Quiz des faux amis',
          ModeQuiz.expressions => 'Quiz des expressions',
          ModeQuiz.trous => 'Phrases à trous',
        }),
      ),
      body: questions == null
          ? const Center(child: CircularProgressIndicator())
          : questions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Pas assez de mots avec un équivalent français pour faire un quiz.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _courante >= questions.length
                  ? _Resultat(score: _score, total: questions.length)
                  : _vue(context, questions[_courante], questions.length),
    );
  }

  Widget _vue(BuildContext context, _Question q, int total) {
    final theme = Theme.of(context);
    final repondu = _choix != null;
    return ListView(
      padding: padPage(context, v: 16),
      children: [
        LinearProgressIndicator(value: _courante / total),
        const SizedBox(height: 8),
        Text('Question ${_courante + 1} sur $total · score $_score',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(q.intitule,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        for (final option in q.options) _Option(
          texte: option,
          etat: !repondu
              ? _Etat.neutre
              : option == q.bonne
                  ? _Etat.bonne
                  : option == _choix
                      ? _Etat.fausse
                      : _Etat.neutre,
          surAppui: repondu ? null : () => _repondre(option),
        ),
        if (repondu) ...[
          const SizedBox(height: 12),
          Text(_choix == q.bonne ? 'Bonne réponse !' : 'Ce n\'était pas ça : « ${q.bonne} ».',
              style: theme.textTheme.titleMedium),
          if (q.explication.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(q.explication, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _suivante,
            child: Text(_courante + 1 >= total ? 'Voir le score' : 'Question suivante'),
          ),
        ],
      ],
    );
  }
}

enum _Etat { neutre, bonne, fausse }

class _Option extends StatelessWidget {
  const _Option({required this.texte, required this.etat, required this.surAppui});

  final String texte;
  final _Etat etat;
  final VoidCallback? surAppui;

  @override
  Widget build(BuildContext context) {
    Color? fond;
    Color? texteCouleur;
    IconData? icone;
    if (etat == _Etat.bonne) {
      fond = const Color(0xFF1B5E20);
      texteCouleur = Colors.white;
      icone = Icons.check_circle_rounded;
    } else if (etat == _Etat.fausse) {
      fond = const Color(0xFF8E0000);
      texteCouleur = Colors.white;
      icone = Icons.cancel_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: fond,
          foregroundColor: texteCouleur,
          disabledForegroundColor: texteCouleur,
          disabledBackgroundColor: fond,
          alignment: Alignment.centerLeft,
        ),
        onPressed: surAppui,
        child: Row(
          children: [
            Expanded(child: Text(texte, style: const TextStyle(fontSize: 18))),
            if (icone != null) Icon(icone, color: texteCouleur),
          ],
        ),
      ),
    );
  }
}

class _Resultat extends StatelessWidget {
  const _Resultat({required this.score, required this.total});

  final int score;
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
            Text('$score / $total', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              score == total
                  ? 'Sans faute !'
                  : score * 2 >= total
                      ? 'Bien joué, continuez.'
                      : 'Les mots ratés reviendront dans vos révisions.',
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
