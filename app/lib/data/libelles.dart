/// Libellés français des natures, genres et balises du Wiktionnaire.
library;

const Map<String, String> _natures = {
  'noun': 'nom',
  'verb': 'verbe',
  'adj': 'adjectif',
  'adv': 'adverbe',
  'intj': 'interjection',
  'name': 'nom propre',
  'prep': 'préposition',
  'pron': 'pronom',
  'conj': 'conjonction',
  'det': 'déterminant',
  'num': 'nombre',
  'phrase': 'locution',
  'prep_phrase': 'locution',
  'prefix': 'préfixe',
  'suffix': 'suffixe',
  'abbrev': 'abréviation',
  'contraction': 'contraction',
  'article': 'article',
  'particle': 'particule',
  'symbol': 'symbole',
  'proverb': 'proverbe',
  'character': 'caractère',
};

String natureFr(String nature) => _natures[nature] ?? nature;

String genreFr(String genre) => switch (genre) {
      'm' => 'masc.',
      'f' => 'fém.',
      'mf' => 'masc. ou fém.',
      _ => '',
    };

const Map<String, String> _balises = {
  'past': 'passé',
  'participle': 'participe',
  'present': 'présent',
  'plural': 'pluriel',
  'singular': 'singulier',
  'comparative': 'comparatif',
  'superlative': 'superlatif',
  'third-person': '3e personne',
  'gerund': 'participe présent',
  'infinitive': 'infinitif',
  'archaic': 'archaïque',
  'informal': 'familier',
  'slang': 'argot',
  'dated': 'vieilli',
  'rare': 'rare',
  'uk': 'britannique',
  'us': 'américain',
  'obsolete': 'désuet',
  'formal': 'soutenu',
  'literary': 'littéraire',
  'vulgar': 'vulgaire',
  'offensive': 'injurieux',
  'colloquial': 'familier',
  'transitive': 'transitif',
  'intransitive': 'intransitif',
};

/// « participle, past » -> « participe, passé ». Les balises inconnues restent telles quelles.
String baliseFr(String etiquettes) {
  if (etiquettes.trim().isEmpty) return '';
  return etiquettes
      .split(RegExp(r'[,;]\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => _balises[e.toLowerCase()] ?? e)
      .join(', ');
}

/// Types d'expressions, dans l'ordre des filtres de l'écran « Expressions ».
const List<String> typesExpression = ['idiome', 'utile', 'proverbe', 'particule', 'courante'];

String typeExpressionFr(String type) => switch (type) {
      'idiome' => 'Idiomes',
      'utile' => 'Phrases utiles',
      'proverbe' => 'Proverbes',
      'particule' => 'Verbes à particule',
      'courante' => 'Expressions courantes',
      _ => type,
    };

String typeExpressionUnFr(String type) => switch (type) {
      'idiome' => 'idiome',
      'utile' => 'phrase utile',
      'proverbe' => 'proverbe',
      'particule' => 'verbe à particule',
      'courante' => 'expression courante',
      _ => type,
    };

String registreFr(String registre) => switch (registre) {
      'vulgaire' => 'vulgaire',
      'argot' => 'argot',
      'familier' => 'familier',
      'vieilli' => 'vieilli',
      _ => '',
    };

/// Thèmes des phrases utiles et des idiomes.
const Map<String, String> themesExpression = {
  'politesse': 'Politesse',
  'rencontre': 'Rencontre',
  'voyage': 'Voyage',
  'hotel': 'Hôtel',
  'restaurant': 'Restaurant',
  'achats': 'Achats',
  'sante': 'Santé',
  'urgence': 'Urgence',
  'telephone': 'Téléphone',
  'travail': 'Travail',
  'corps': 'Corps',
  'animaux': 'Animaux',
  'nourriture': 'Nourriture',
  'meteo': 'Météo',
  'argent': 'Argent',
  'temps': 'Temps',
  'emotions': 'Émotions',
  'communication': 'Communication',
  'divers': 'Divers',
};
