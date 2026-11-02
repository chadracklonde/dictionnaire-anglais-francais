import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

/// Texte de la ligne [i] du temps [titre].
String ligne(Conjugaison c, String titre, int i) {
  for (final g in c.groupes) {
    for (final t in g.temps) {
      if (t.titre == titre) return t.lignes[i].texte;
    }
  }
  throw StateError('temps introuvable : $titre');
}

void main() {
  group('formes', () {
    void verifie(String verbe, String troisieme, String passe, String participe, String gerondif) {
      final f = formesVerbe(verbe);
      expect(
        [f.troisieme, f.passe, f.participePasse, f.participePresent],
        [troisieme, passe, participe, gerondif],
        reason: verbe,
      );
    }

    test('verbes réguliers', () {
      verifie('walk', 'walks', 'walked', 'walked', 'walking');
      verifie('love', 'loves', 'loved', 'loved', 'loving');
      verifie('stop', 'stops', 'stopped', 'stopped', 'stopping');
      verifie('study', 'studies', 'studied', 'studied', 'studying');
      verifie('play', 'plays', 'played', 'played', 'playing');
      verifie('visit', 'visits', 'visited', 'visited', 'visiting');
      verifie('admit', 'admits', 'admitted', 'admitted', 'admitting');
      verifie('watch', 'watches', 'watched', 'watched', 'watching');
      verifie('fix', 'fixes', 'fixed', 'fixed', 'fixing');
      verifie('see', 'sees', 'saw', 'seen', 'seeing');
      verifie('picnic', 'picnics', 'picnicked', 'picnicked', 'picnicking');
      verifie('die', 'dies', 'died', 'died', 'dying');
      verifie('help', 'helps', 'helped', 'helped', 'helping');
    });

    test('verbes irréguliers', () {
      verifie('go', 'goes', 'went', 'gone', 'going');
      verifie('do', 'does', 'did', 'done', 'doing');
      verifie('have', 'has', 'had', 'had', 'having');
      verifie('make', 'makes', 'made', 'made', 'making');
      verifie('run', 'runs', 'ran', 'run', 'running');
      verifie('begin', 'begins', 'began', 'begun', 'beginning');
      verifie('take', 'takes', 'took', 'taken', 'taking');
      verifie('overcome', 'overcomes', 'overcame', 'overcome', 'overcoming');
      verifie('withdraw', 'withdraws', 'withdrew', 'withdrawn', 'withdrawing');
    });

    test('verbe à particule', () {
      final f = formesVerbe('give up');
      expect(f.infinitif, 'give up');
      expect(f.avecQueue(f.passe), 'gave up');
      expect(f.avecQueue(f.participePasse), 'given up');
      expect(f.avecQueue(f.troisieme), 'gives up');
    });

    test('les formes de la base passent avant les règles', () {
      final f = formesVerbe('dream', const [
        Forme('dreamt', 'past'),
        Forme('dreamt', 'participle, past'),
        Forme('dreaming', 'participle, present'),
        Forme('dreams', 'third-person, singular, present'),
      ]);
      expect(f.passe, 'dreamt');
      expect(f.participePasse, 'dreamt');
      expect(f.troisieme, 'dreams');
    });

    test('une forme de la base pour un verbe à particule garde la particule à part', () {
      final f = formesVerbe('give up', const [Forme('gave up', 'past'), Forme('given up', 'participle, past')]);
      expect(f.passe, 'gave');
      expect(f.participePasse, 'given');
    });

    test('formes de la base ignorant les balises de tableau', () {
      final f = formesVerbe('walk', const [Forme('no-table-tags', 'table-tags')]);
      expect(f.passe, 'walked');
    });
  });

  group('temps', () {
    test('verbe régulier, affirmatif', () {
      final c = conjuguer('go');
      expect(ligne(c, 'Présent simple', 0), 'I go');
      expect(ligne(c, 'Présent simple', 2), 'he / she / it goes');
      expect(ligne(c, 'Présent continu', 0), 'I am going');
      expect(ligne(c, 'Présent continu', 5), 'they are going');
      expect(ligne(c, 'Prétérit', 3), 'we went');
      expect(ligne(c, 'Prétérit continu', 2), 'he / she / it was going');
      expect(ligne(c, 'Présent parfait', 2), 'he / she / it has gone');
      expect(ligne(c, 'Plus-que-parfait', 0), 'I had gone');
      expect(ligne(c, 'Futur simple', 5), 'they will go');
      expect(ligne(c, 'Futur antérieur', 0), 'I will have gone');
      expect(ligne(c, 'Conditionnel présent', 1), 'you would go');
      expect(ligne(c, 'Conditionnel passé', 1), 'you would have gone');
      expect(c.groupes.map((g) => g.titre), ['Indicatif', 'Conditionnel', 'Impératif', 'Formes du verbe']);
    });

    test('forme négative', () {
      final c = conjuguer('go', polarite: Polarite.negative);
      expect(ligne(c, 'Présent simple', 2), 'he / she / it does not go');
      expect(ligne(c, 'Prétérit', 0), 'I did not go');
      expect(ligne(c, 'Présent parfait', 0), 'I have not gone');
      expect(ligne(c, 'Futur simple', 0), 'I will not go');
      expect(ligne(c, 'Impératif', 0), 'Do not go');
    });

    test('forme interrogative', () {
      final c = conjuguer('go', polarite: Polarite.interrogative);
      expect(ligne(c, 'Présent simple', 0), 'Do I go ?');
      expect(ligne(c, 'Présent simple', 2), 'Does he / she / it go ?');
      expect(ligne(c, 'Prétérit', 3), 'Did we go ?');
      expect(ligne(c, 'Présent continu', 1), 'Are you going ?');
      expect(c.groupes.map((g) => g.titre), isNot(contains('Impératif')));
    });

    test('le verbe être', () {
      final c = conjuguer('be');
      expect(ligne(c, 'Présent simple', 0), 'I am');
      expect(ligne(c, 'Présent simple', 2), 'he / she / it is');
      expect(ligne(c, 'Prétérit', 1), 'you were');
      expect(ligne(c, 'Prétérit', 0), 'I was');
      expect(ligne(c, 'Présent continu', 0), 'I am being');
      expect(ligne(c, 'Présent parfait', 0), 'I have been');
      expect(ligne(c, 'Futur simple', 0), 'I will be');
      expect(ligne(conjuguer('be', polarite: Polarite.negative), 'Présent simple', 2), 'he / she / it is not');
      expect(ligne(conjuguer('be', polarite: Polarite.interrogative), 'Prétérit', 0), 'Was I ?');
    });

    test('verbe à particule', () {
      final c = conjuguer('give up');
      expect(ligne(c, 'Présent simple', 2), 'he / she / it gives up');
      expect(ligne(c, 'Prétérit', 0), 'I gave up');
      expect(ligne(c, 'Présent parfait', 0), 'I have given up');
      expect(ligne(c, 'Futur simple', 0), 'I will give up');
      expect(ligne(conjuguer('give up', polarite: Polarite.negative), 'Prétérit', 0), 'I did not give up');
    });

    test('verbe défectif', () {
      final c = conjuguer('can');
      expect(c.groupes.single.temps.first.titre, 'Présent');
      expect(ligne(c, 'Présent', 2), 'he / she / it can [verbe]');
      expect(ligne(c, 'Forme passée ou conditionnelle', 0), 'I could [verbe]');
      expect(ligne(conjuguer('can', polarite: Polarite.negative), 'Présent', 0), 'I cannot [verbe]');
      expect(ligne(conjuguer('can', polarite: Polarite.interrogative), 'Présent', 0), 'Can I [verbe] ?');
      expect(c.notes, isNotEmpty);
      expect(conjuguer('must').groupes.single.temps.length, 1);
    });

    test('formes du verbe', () {
      final c = conjuguer('take');
      final formes = c.groupes.last.temps.single.lignes.map((l) => '${l.sujet}: ${l.texte}').toList();
      expect(formes, contains('Infinitif avec « to »: to take'));
      expect(formes, contains('Participe passé: taken'));
      expect(formes, contains('Participe présent: taking'));
    });

    test('plusieurs formes possibles', () {
      final c = conjuguer('learn');
      expect(c.formes.passe, 'learned / learnt');
      expect(c.notes, isNotEmpty);
    });
  });
}
