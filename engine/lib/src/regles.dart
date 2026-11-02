/// Règles qui retrouvent le mot de base quand la base ne connaît pas la forme saisie.
library;

/// Un mot de base probable et ce que la règle suppose (« passé ou participe passé »).
class Candidat {
  const Candidat(this.lemme, this.description);

  final String lemme;
  final String description;
}

const String _voyelles = 'aeiou';

bool _consonne(String lettre) => lettre.isNotEmpty && !_voyelles.contains(lettre) && RegExp('[a-z]').hasMatch(lettre);

/// « world's » → « world », « dogs' » → « dogs ». Renvoie null si le mot n'est pas un possessif.
String? sansPossessif(String mot) {
  final m = mot.replaceAll('’', "'");
  if (m.length > 3 && m.endsWith("'s")) return m.substring(0, m.length - 2);
  if (m.length > 3 && m.endsWith("s'")) return m.substring(0, m.length - 1);
  return null;
}

/// Mots de base possibles d'une forme anglaise régulière, du plus au moins probable.
/// Tous les candidats ne sont pas de vrais mots : le moteur essaie dans l'ordre jusqu'à en trouver un.
List<Candidat> candidatsLemmes(String mot) {
  final m = mot.toLowerCase();
  final sortie = <Candidat>[];
  void ajouter(String lemme, String description) {
    if (lemme.length >= 2 && lemme != m && !sortie.any((c) => c.lemme == lemme)) {
      sortie.add(Candidat(lemme, description));
    }
  }

  String sans(int n) => m.substring(0, m.length - n);
  bool doublee(int n) {
    // consonne doublée juste avant la terminaison de n lettres : stopped, running, bigger
    final s = sans(n);
    return s.length >= 3 && s[s.length - 1] == s[s.length - 2] && _consonne(s[s.length - 1]);
  }

  if (m.length < 3 || !RegExp(r"^[a-z' -]+$").hasMatch(m)) return sortie;

  // pluriel des noms, 3e personne des verbes
  const pluriel = 'pluriel ou 3ᵉ personne du singulier';
  if (m.endsWith('ies') && m.length > 4) ajouter('${sans(3)}y', pluriel);
  if (m.endsWith('ves') && m.length > 4) {
    ajouter('${sans(3)}f', pluriel);
    ajouter('${sans(3)}fe', pluriel);
  }
  if (m.endsWith('es') && m.length > 3) {
    if (RegExp(r'(s|x|z|ch|sh|o)es$').hasMatch(m)) ajouter(sans(2), pluriel);
    ajouter(sans(1), pluriel);
  }
  if (m.endsWith('s') && !m.endsWith('ss') && m.length > 2) ajouter(sans(1), pluriel);

  // passé et participe passé
  const passe = 'passé ou participe passé';
  if (m.endsWith('ied') && m.length > 4) ajouter('${sans(3)}y', passe);
  if (m.endsWith('ed') && m.length > 3) {
    if (doublee(2)) ajouter(sans(3), passe);
    ajouter(sans(2), passe);
    ajouter(sans(1), passe);
    if (m.endsWith('cked') && m.length > 5) ajouter(sans(3), passe);
  }

  // participe présent
  const gerondif = 'participe présent';
  if (m.endsWith('ying') && m.length > 4) ajouter('${sans(4)}ie', gerondif);
  if (m.endsWith('ing') && m.length > 4) {
    if (doublee(3)) ajouter(sans(4), gerondif);
    ajouter(sans(3), gerondif);
    ajouter('${sans(3)}e', gerondif);
    if (m.endsWith('cking') && m.length > 6) ajouter(sans(4), gerondif);
  }

  // comparatif et superlatif
  const comparatif = 'comparatif';
  const superlatif = 'superlatif';
  if (m.endsWith('ier') && m.length > 4) ajouter('${sans(3)}y', comparatif);
  if (m.endsWith('er') && m.length > 3) {
    if (doublee(2)) ajouter(sans(3), comparatif);
    ajouter(sans(2), comparatif);
    ajouter(sans(1), comparatif);
  }
  if (m.endsWith('iest') && m.length > 5) ajouter('${sans(4)}y', superlatif);
  if (m.endsWith('est') && m.length > 4) {
    if (doublee(3)) ajouter(sans(4), superlatif);
    ajouter(sans(3), superlatif);
    ajouter(sans(2), superlatif);
  }

  // adverbes en -ly
  const adverbe = 'adverbe';
  if (m.endsWith('ily') && m.length > 4) ajouter('${sans(3)}y', adverbe);
  if (m.endsWith('ly') && m.length > 4) ajouter(sans(2), adverbe);
  return sortie;
}

/// Mots de base possibles d'un mot français (pluriel, féminin). Les formes conjuguées des verbes
/// français ne sont pas dans la base : elles ne sont pas couvertes. Le texte est déjà plié.
List<Candidat> candidatsFrancais(String mot) {
  final m = mot.toLowerCase();
  final sortie = <Candidat>[];
  void ajouter(String lemme, String description) {
    if (lemme.length >= 2 && lemme != m && !sortie.any((c) => c.lemme == lemme)) {
      sortie.add(Candidat(lemme, description));
    }
  }

  String sans(int n) => m.substring(0, m.length - n);
  if (m.length < 4) return sortie;
  if (m.endsWith('eaux')) ajouter(sans(1), 'pluriel');
  if (m.endsWith('aux')) ajouter('${sans(3)}al', 'pluriel');
  if (m.endsWith('s') || m.endsWith('x')) ajouter(sans(1), 'pluriel');
  if (m.endsWith('es')) ajouter(sans(1), 'féminin pluriel');
  if (m.endsWith('es')) ajouter(sans(2), 'féminin pluriel');
  if (m.endsWith('e')) ajouter(sans(1), 'féminin');
  if (m.endsWith('euse')) ajouter('${sans(4)}eur', 'féminin');
  if (m.endsWith('trice')) ajouter('${sans(5)}teur', 'féminin');
  if (m.endsWith('ive')) ajouter('${sans(3)}if', 'féminin');
  return sortie;
}
