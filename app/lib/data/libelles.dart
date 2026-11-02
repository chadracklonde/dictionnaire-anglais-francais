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
