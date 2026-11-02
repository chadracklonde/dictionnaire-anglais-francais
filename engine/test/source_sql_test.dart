import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:test/test.dart';

class ExecuteurFactice implements ExecuteurSql {
  ExecuteurFactice(this.reponses);

  final List<List<Map<String, Object?>>> reponses;
  final List<String> requetes = [];
  final List<List<Object?>> arguments = [];

  @override
  Future<List<Map<String, Object?>>> requete(String sql, [List<Object?> args = const []]) async {
    requetes.add(sql);
    arguments.add(args);
    return reponses.isEmpty ? const [] : reponses.removeAt(0);
  }
}

void main() {
  test('motsParRecherche lit les lignes et passe le texte plié', () async {
    final e = ExecuteurFactice([
      [
        {'id': 1, 'mot': 'go', 'nature': 'verb', 'rang': 5},
        {'id': 2, 'mot': 'Go', 'nature': 'name', 'rang': null},
      ],
    ]);
    final mots = await SourceSql(e).motsParRecherche('go');
    expect(e.requetes.single, requeteMotsParRecherche);
    expect(e.arguments.single, ['go']);
    expect(mots.map((m) => m.mot), ['go', 'Go']);
    expect(mots.first.rang, 5);
    expect(mots.last.rang, isNull);
  });

  test('lemmesDeForme', () async {
    final e = ExecuteurFactice([
      [
        {'id': 1, 'mot': 'go', 'nature': 'verb', 'rang': 5, 'etiquettes': 'past'},
      ],
    ]);
    final renvois = await SourceSql(e).lemmesDeForme('went');
    expect(e.requetes.single, requeteLemmesDeForme);
    expect(renvois.single.lemme.mot, 'go');
    expect(renvois.single.etiquettes, 'past');
  });

  test('contraction absente puis présente', () async {
    final e = ExecuteurFactice([
      [],
      [
        {'forme': "can't", 'developpe': 'cannot', 'traduction': 'ne peut pas'},
      ],
    ]);
    final source = SourceSql(e);
    expect(await source.contraction('xyz'), isNull);
    final c = await source.contraction("can't");
    expect(c?.traduction, 'ne peut pas');
  });

  test('équivalents, sens, formes, audio, prononciations', () async {
    final e = ExecuteurFactice([
      [
        {'fr': 'aller', 'etiquette': 'to move', 'genre': '', 'source': 'en+fr'},
      ],
      [
        {'ordre': 1, 'definition': 'To move.', 'contexte': '', 'etiquettes': 'intransitive', 'exemple': null},
      ],
      [
        {'forme': 'went', 'etiquettes': 'past'},
      ],
      [
        {'fichier': 'En-us-go.ogg', 'accent': 'us'},
      ],
      [
        {'accent': 'uk', 'api': '/ɡəʊ/'},
      ],
    ]);
    final source = SourceSql(e);
    final equivalents = await source.equivalents(1);
    expect(equivalents.single.confirme, isTrue);
    final sens = await source.sens(1);
    expect(sens.single.exemple, '');
    expect((await source.formes(1)).single.forme, 'went');
    expect((await source.audio(1)).single.accent, 'us');
    expect((await source.prononciations(1)).single.api, '/ɡəʊ/');
    expect(e.arguments.every((a) => a.length == 1 && a.first == 1), isTrue);
  });

  test('anglaisParFrancais passe la limite', () async {
    final e = ExecuteurFactice([
      [
        {
          'id': 3,
          'mot': 'dog',
          'nature': 'noun',
          'rang': 80,
          'fr': 'chien',
          'etiquette': '',
          'genre': 'm',
          'source': 'en+fr',
        },
      ],
    ]);
    final lignes = await SourceSql(e).anglaisParFrancais('chien', 50);
    expect(e.arguments.single, ['chien', 50]);
    expect(lignes.single.mot.mot, 'dog');
    expect(lignes.single.equivalent.genre, 'm');
  });

  test('suggestions : borne supérieure du préfixe', () async {
    final e = ExecuteurFactice([
      [
        {'mot': 'world'},
      ],
      [
        {'fr': 'monde'},
      ],
    ]);
    final source = SourceSql(e);
    expect(await source.suggestionsAnglais('wo', 5), ['world']);
    expect(await source.suggestionsFrancais('mo', 5), ['monde']);
    expect(e.arguments.first, ['wo', 'wo￿', 5]);
    expect(e.requetes.first, requeteSuggestionsAnglais);
    expect(e.requetes.last, requeteSuggestionsFrancais);
  });
}
