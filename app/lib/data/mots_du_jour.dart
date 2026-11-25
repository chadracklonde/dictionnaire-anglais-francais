/// Mots courants proposés tour à tour comme « mot du jour » (choisi d'après la date, sans réseau).
const List<String> motsDuJour = [
  'achieve', 'borrow', 'cheap', 'deliver', 'enough', 'forget', 'gather', 'handle', 'improve',
  'journey', 'knowledge', 'lend', 'manage', 'neighbour', 'obvious', 'perhaps', 'quarrel',
  'reach', 'suggest', 'though', 'understand', 'various', 'wander', 'yield', 'ancient', 'balance',
  'challenge', 'decide', 'effort', 'freedom', 'grateful', 'honest', 'imagine', 'jealous',
  'kindness', 'language', 'mistake', 'nearby', 'opinion', 'patient', 'quiet', 'receive',
  'safe', 'trust', 'unusual', 'value', 'weather', 'anxious', 'believe', 'courage', 'dream',
  'enjoy', 'friendship', 'growth', 'harvest', 'island', 'joy', 'knit', 'lonely', 'memory',
  'notice', 'offer', 'promise', 'remember', 'shelter', 'travel', 'unite', 'village', 'welcome',
  'yearn', 'zeal', 'bridge', 'choose', 'desire', 'engage', 'follow', 'guess', 'hesitate',
  'invite', 'judge', 'lack', 'matter', 'owe', 'prefer', 'rarely', 'search', 'tend', 'wonder',
];

String motDuJour(DateTime maintenant) {
  final jour = maintenant.difference(DateTime(2026)).inDays;
  return motsDuJour[jour.abs() % motsDuJour.length];
}
