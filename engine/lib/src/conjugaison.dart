/// Conjugaison anglaise : formes de la base d'abord, table des verbes irréguliers courants,
/// puis règles d'orthographe. Les temps composés sont produits par règles.
library;

import 'modeles.dart';

enum Polarite { affirmative, negative, interrogative }

const List<String> sujets = ['I', 'you', 'he / she / it', 'we', 'you', 'they'];

const List<String> _bePresent = ['am', 'are', 'is', 'are', 'are', 'are'];
const List<String> _bePasse = ['was', 'were', 'was', 'were', 'were', 'were'];
const List<String> _havePresent = ['have', 'have', 'has', 'have', 'have', 'have'];
const List<String> _doPresent = ['do', 'do', 'does', 'do', 'do', 'do'];

/// Verbes défectifs : pas de -s à la 3ᵉ personne, pas d'infinitif. Valeur : forme passée / conditionnelle.
const Map<String, String> _modaux = {
  'can': 'could',
  'may': 'might',
  'shall': 'should',
  'will': 'would',
  'must': '',
  'ought': '',
};

/// Verbes irréguliers : base, passé, participe passé (variantes séparées par « / »).
const String _tableBrute = '''
arise arose arisen
awake awoke awoken
bear bore borne/born
beat beat beaten
become became become
begin began begun
bend bent bent
bet bet bet
bid bid bid
bind bound bound
bite bit bitten
bleed bled bled
blow blew blown
break broke broken
breed bred bred
bring brought brought
build built built
burn burned/burnt burned/burnt
burst burst burst
buy bought bought
cast cast cast
catch caught caught
choose chose chosen
cling clung clung
come came come
cost cost cost
creep crept crept
cut cut cut
deal dealt dealt
dig dug dug
do did done
draw drew drawn
dream dreamed/dreamt dreamed/dreamt
drink drank drunk
drive drove driven
eat ate eaten
fall fell fallen
feed fed fed
feel felt felt
fight fought fought
find found found
flee fled fled
fling flung flung
fly flew flown
forbid forbade forbidden
forget forgot forgotten
forgive forgave forgiven
freeze froze frozen
get got got/gotten
give gave given
go went gone
grind ground ground
grow grew grown
hang hung hung
have had had
hear heard heard
hide hid hidden
hit hit hit
hold held held
hurt hurt hurt
keep kept kept
kneel knelt/kneeled knelt/kneeled
know knew known
lay laid laid
lead led led
lean leaned/leant leaned/leant
leap leaped/leapt leaped/leapt
learn learned/learnt learned/learnt
leave left left
lend lent lent
let let let
lie lay lain
light lit lit
lose lost lost
make made made
mean meant meant
meet met met
pay paid paid
put put put
quit quit quit
read read read
ride rode ridden
ring rang rung
rise rose risen
run ran run
say said said
see saw seen
seek sought sought
sell sold sold
send sent sent
set set set
sew sewed sewn/sewed
shake shook shaken
shine shone shone
shoot shot shot
show showed shown/showed
shrink shrank shrunk
shut shut shut
sing sang sung
sink sank sunk
sit sat sat
sleep slept slept
slide slid slid
speak spoke spoken
speed sped sped
spell spelled/spelt spelled/spelt
spend spent spent
spill spilled/spilt spilled/spilt
spin spun spun
spit spat spat
split split split
spread spread spread
spring sprang sprung
stand stood stood
steal stole stolen
stick stuck stuck
sting stung stung
stink stank stunk
strike struck struck
swear swore sworn
sweep swept swept
swim swam swum
swing swung swung
take took taken
teach taught taught
tear tore torn
tell told told
think thought thought
throw threw thrown
understand understood understood
wake woke woken
wear wore worn
weave wove woven
weep wept wept
win won won
wind wound wound
withdraw withdrew withdrawn
write wrote written
''';

const List<String> _prefixesIrreguliers = [
  'over', 'under', 'out', 'up', 'mis', 'fore', 'with', 're', 'un', 'be', 'for',
];

/// Verbes dont la dernière syllabe est accentuée : la consonne finale est doublée (admit → admitted).
const Set<String> _accentFinale = {
  'admit', 'commit', 'permit', 'submit', 'omit', 'refer', 'prefer', 'defer', 'confer', 'transfer',
  'occur', 'incur', 'recur', 'begin', 'regret', 'control', 'compel', 'expel', 'repel', 'equip',
  'deter', 'infer', 'program', 'forget', 'patrol', 'upset', 'rebel', 'propel', 'excel',
};

final Map<String, List<String>> _irreguliers = _lireTable(_tableBrute);

Map<String, List<String>> _lireTable(String brut) {
  final table = <String, List<String>>{};
  for (final ligne in brut.split('\n')) {
    final c = ligne.trim().split(' ');
    if (c.length != 3) continue;
    table[c[0]] = [c[1].replaceAll('/', ' / '), c[2].replaceAll('/', ' / ')];
  }
  return table;
}

/// Passé et participe passé d'un verbe irrégulier, avec ses composés (overcome, withdraw…).
List<String>? _irregulier(String verbe) {
  final direct = _irreguliers[verbe];
  if (direct != null) return direct;
  for (final prefixe in _prefixesIrreguliers) {
    if (!verbe.startsWith(prefixe)) continue;
    final reste = verbe.substring(prefixe.length);
    final base = _irreguliers[reste];
    if (base != null && reste.length >= 3) {
      return [for (final f in base) f.split(' / ').map((v) => '$prefixe$v').join(' / ')];
    }
  }
  return null;
}

bool _voyelle(String lettre) => 'aeiou'.contains(lettre);
bool _consonne(String lettre) => RegExp('[a-z]').hasMatch(lettre) && !_voyelle(lettre);

int _groupesVoyelles(String mot) => RegExp('[aeiouy]+').allMatches(mot).length;

/// La consonne finale est-elle doublée devant -ed / -ing ? (stop → stopped ; visit → visited)
bool consonneDoublee(String verbe) {
  if (verbe.length < 3) return false;
  final dernier = verbe[verbe.length - 1];
  if (!_consonne(dernier) || 'wxy'.contains(dernier)) return false;
  if (_accentFinale.contains(verbe)) return true;
  final avant = verbe[verbe.length - 2];
  final avantAvant = verbe[verbe.length - 3];
  return _voyelle(avant) && _consonne(avantAvant) && _groupesVoyelles(verbe) == 1;
}

String troisiemePersonne(String verbe) {
  if (verbe == 'have') return 'has';
  if (verbe == 'be') return 'is';
  if (RegExp(r'(s|x|z|ch|sh)$').hasMatch(verbe)) return '${verbe}es';
  if (verbe.endsWith('y') && verbe.length > 1 && _consonne(verbe[verbe.length - 2])) {
    return '${verbe.substring(0, verbe.length - 1)}ies';
  }
  if (verbe.endsWith('o') && verbe.length > 1 && _consonne(verbe[verbe.length - 2])) return '${verbe}es';
  return '${verbe}s';
}

String passeRegulier(String verbe) {
  if (verbe.endsWith('e')) return '${verbe}d';
  if (verbe.endsWith('y') && verbe.length > 1 && _consonne(verbe[verbe.length - 2])) {
    return '${verbe.substring(0, verbe.length - 1)}ied';
  }
  if (verbe.endsWith('ic')) return '${verbe}ked';
  if (consonneDoublee(verbe)) return '$verbe${verbe[verbe.length - 1]}ed';
  return '${verbe}ed';
}

String participePresentRegulier(String verbe) {
  if (verbe == 'be') return 'being';
  if (verbe.endsWith('ie')) return '${verbe.substring(0, verbe.length - 2)}ying';
  if (verbe.endsWith('e') && !RegExp(r'(ee|ye|oe)$').hasMatch(verbe) && verbe.length > 2) {
    return '${verbe.substring(0, verbe.length - 1)}ing';
  }
  if (verbe.endsWith('ic')) return '${verbe}king';
  if (consonneDoublee(verbe)) return '$verbe${verbe[verbe.length - 1]}ing';
  return '${verbe}ing';
}

/// Les formes dont dépendent tous les temps. [queue] : particule d'un verbe à particule (give « up »).
class FormesVerbe {
  const FormesVerbe({
    required this.base,
    required this.troisieme,
    required this.passe,
    required this.participePasse,
    required this.participePresent,
    this.queue = '',
  });

  final String base;
  final String troisieme;
  final String passe;
  final String participePasse;
  final String participePresent;
  final String queue;

  String avecQueue(String forme) => queue.isEmpty ? forme : '$forme $queue';

  String get infinitif => avecQueue(base);
}

/// Formes d'un verbe : celles de la base ([formesBdd]) si elles existent, sinon la table des
/// irréguliers, sinon les règles d'orthographe.
FormesVerbe formesVerbe(String verbe, [List<Forme> formesBdd = const []]) {
  final propre = verbe.trim().toLowerCase();
  final espace = propre.indexOf(' ');
  final tete = espace < 0 ? propre : propre.substring(0, espace);
  final queue = espace < 0 ? '' : propre.substring(espace + 1);

  String? troisieme;
  String? passe;
  String? participePasse;
  String? participePresent;
  for (final f in formesBdd) {
    var texte = f.forme.trim().toLowerCase();
    if (queue.isNotEmpty) {
      if (!texte.endsWith(' $queue')) continue;
      texte = texte.substring(0, texte.length - queue.length - 1);
    }
    if (texte.isEmpty || texte.contains(' ')) continue;
    final tags = f.etiquettes.split(',').map((t) => t.trim().toLowerCase()).toSet();
    if (tags.contains('participle') && tags.contains('present')) {
      participePresent ??= texte;
    } else if (tags.contains('participle') && tags.contains('past')) {
      participePasse ??= texte;
    } else if (tags.contains('past') && !tags.contains('participle')) {
      passe ??= texte;
    } else if (tags.contains('third-person') &&
        tags.contains('singular') &&
        tags.contains('present')) {
      troisieme ??= texte;
    }
  }
  passe ??= participePasse != null && _irregulier(tete) == null ? participePasse : null;

  final irregulier = _irregulier(tete);
  if (tete == 'be') {
    return FormesVerbe(
      base: 'be',
      troisieme: 'is',
      passe: 'was / were',
      participePasse: 'been',
      participePresent: 'being',
      queue: queue,
    );
  }
  return FormesVerbe(
    base: tete,
    troisieme: troisieme ?? troisiemePersonne(tete),
    passe: passe ?? (irregulier != null ? irregulier[0] : passeRegulier(tete)),
    participePasse: participePasse ??
        (irregulier != null
            ? irregulier[1]
            : (passe != null ? passe.split(' / ').first : passeRegulier(tete))),
    participePresent: participePresent ?? participePresentRegulier(tete),
    queue: queue,
  );
}

class LigneConjugaison {
  const LigneConjugaison(this.sujet, this.texte);

  final String sujet;
  final String texte;
}

class TempsConjugue {
  const TempsConjugue(this.titre, this.lignes);

  final String titre;
  final List<LigneConjugaison> lignes;
}

class GroupeConjugaison {
  const GroupeConjugaison(this.titre, this.temps);

  final String titre;
  final List<TempsConjugue> temps;
}

class Conjugaison {
  const Conjugaison({
    required this.infinitif,
    required this.formes,
    required this.polarite,
    required this.groupes,
    this.notes = const [],
  });

  final String infinitif;
  final FormesVerbe formes;
  final Polarite polarite;
  final List<GroupeConjugaison> groupes;
  final List<String> notes;
}

String _majuscule(String texte) =>
    texte.isEmpty ? texte : '${texte[0].toUpperCase()}${texte.substring(1)}';

String _joindre(List<String> morceaux) => morceaux.where((m) => m.isNotEmpty).join(' ');

String _auxNegatif(String aux) => aux == 'can' ? 'cannot' : '$aux not';

/// Une phrase avec auxiliaire : « I have gone », « I have not gone », « Have I gone ? ».
String _avecAuxiliaire(int i, Polarite p, String aux, String reste) {
  switch (p) {
    case Polarite.affirmative:
      return _joindre([sujets[i], aux, reste]);
    case Polarite.negative:
      return _joindre([sujets[i], _auxNegatif(aux), reste]);
    case Polarite.interrogative:
      return '${_majuscule(_joindre([aux, sujets[i], reste]))} ?';
  }
}

/// Conjugue [verbe]. [formesBdd] : formes listées par la base pour ce verbe (peut être vide).
Conjugaison conjuguer(
  String verbe, {
  List<Forme> formesBdd = const [],
  Polarite polarite = Polarite.affirmative,
}) {
  final f = formesVerbe(verbe, formesBdd);
  final p = polarite;
  final notes = <String>[];
  final estBe = f.base == 'be';
  final modal = _modaux[f.base];
  final estModal = modal != null && f.queue.isEmpty;
  final infinitif = f.infinitif;

  List<LigneConjugaison> lignes(String Function(int i) forme) =>
      [for (var i = 0; i < sujets.length; i++) LigneConjugaison(sujets[i], forme(i))];

  // Présent et passé simples : le verbe lui-même, ou « do » comme auxiliaire.
  String simple(int i, String formeAffirmative, List<String> auxFaire) {
    if (p == Polarite.affirmative) return _joindre([sujets[i], f.avecQueue(formeAffirmative)]);
    return _avecAuxiliaire(i, p, auxFaire[i], infinitif);
  }

  const presentSimple = 'Présent simple';
  const passeSimple = 'Prétérit';

  final temps = <TempsConjugue>[];
  if (estBe) {
    temps.add(TempsConjugue(presentSimple, lignes((i) => _avecAuxiliaire(i, p, _bePresent[i], ''))));
    temps.add(TempsConjugue(passeSimple, lignes((i) => _avecAuxiliaire(i, p, _bePasse[i], ''))));
  } else if (estModal) {
    notes.add('« ${f.base} » est un verbe défectif : même forme à toutes les personnes, '
        'suivi de l\'infinitif sans « to ».');
    temps.add(TempsConjugue('Présent', lignes((i) => _avecAuxiliaire(i, p, f.base, '[verbe]'))));
    if (modal!.isNotEmpty) {
      temps.add(TempsConjugue(
          'Forme passée ou conditionnelle', lignes((i) => _avecAuxiliaire(i, p, modal, '[verbe]'))));
    }
  } else {
    temps.add(TempsConjugue(
        presentSimple, lignes((i) => simple(i, i == 2 ? f.troisieme : f.base, _doPresent))));
    temps.add(TempsConjugue(passeSimple,
        lignes((i) => simple(i, f.passe, const ['did', 'did', 'did', 'did', 'did', 'did']))));
  }

  final groupes = <GroupeConjugaison>[];
  if (estModal) {
    groupes.add(GroupeConjugaison('Formes', temps));
    return Conjugaison(infinitif: infinitif, formes: f, polarite: p, groupes: groupes, notes: notes);
  }

  final indicatif = <TempsConjugue>[
    temps[0],
    TempsConjugue('Présent continu',
        lignes((i) => _avecAuxiliaire(i, p, _bePresent[i], f.avecQueue(f.participePresent)))),
    temps[1],
    TempsConjugue('Prétérit continu',
        lignes((i) => _avecAuxiliaire(i, p, _bePasse[i], f.avecQueue(f.participePresent)))),
    TempsConjugue('Présent parfait',
        lignes((i) => _avecAuxiliaire(i, p, _havePresent[i], f.avecQueue(f.participePasse)))),
    TempsConjugue('Plus-que-parfait',
        lignes((i) => _avecAuxiliaire(i, p, 'had', f.avecQueue(f.participePasse)))),
    TempsConjugue('Futur simple', lignes((i) => _avecAuxiliaire(i, p, 'will', infinitif))),
    TempsConjugue('Futur antérieur',
        lignes((i) => _avecAuxiliaire(i, p, 'will', _joindre(['have', f.avecQueue(f.participePasse)])))),
  ];
  groupes.add(GroupeConjugaison('Indicatif', indicatif));

  groupes.add(GroupeConjugaison('Conditionnel', [
    TempsConjugue('Conditionnel présent', lignes((i) => _avecAuxiliaire(i, p, 'would', infinitif))),
    TempsConjugue('Conditionnel passé',
        lignes((i) => _avecAuxiliaire(i, p, 'would', _joindre(['have', f.avecQueue(f.participePasse)])))),
  ]));

  if (p != Polarite.interrogative) {
    final negatif = p == Polarite.negative;
    groupes.add(GroupeConjugaison('Impératif', [
      TempsConjugue('Impératif', [
        LigneConjugaison('you', _majuscule(negatif ? 'do not $infinitif' : infinitif)),
        LigneConjugaison('we', _majuscule(negatif ? 'let\'s not $infinitif' : 'let\'s $infinitif')),
      ]),
    ]));
  }

  groupes.add(GroupeConjugaison('Formes du verbe', [
    TempsConjugue('Formes', [
      LigneConjugaison('Infinitif', infinitif),
      LigneConjugaison('Infinitif avec « to »', 'to $infinitif'),
      LigneConjugaison('3ᵉ personne du présent', f.avecQueue(f.troisieme)),
      LigneConjugaison('Prétérit', f.avecQueue(f.passe)),
      LigneConjugaison('Participe passé', f.avecQueue(f.participePasse)),
      LigneConjugaison('Participe présent', f.avecQueue(f.participePresent)),
    ]),
  ]));

  if (estBe) notes.add('« be » est le seul verbe qui a des formes différentes à presque toutes les personnes.');
  if (f.passe.contains(' / ') || f.participePasse.contains(' / ')) {
    notes.add('Plusieurs formes existent : la première est la plus courante en anglais américain.');
  }
  return Conjugaison(infinitif: infinitif, formes: f, polarite: p, groupes: groupes, notes: notes);
}
