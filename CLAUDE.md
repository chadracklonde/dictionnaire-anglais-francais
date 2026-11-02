# Dictionnaire Anglais-Français — dossier de reprise du projet

> Lu automatiquement par Claude Code à l'ouverture du dépôt. **Aucun mot de passe ici** : les secrets
> sont décrits (où ils sont, comment ils s'appellent), jamais écrits.
> Dernière mise à jour : 2 novembre 2026 · état : phases 0 à 2 faites (§9-§11), phase 3 écrite (§12) en attente de validation par la CI `build.yml`, rien de publié.

## 1. En bref

- **Nom** : Dictionnaire Anglais-Français — application à part entière, distincte de
  « Dictionnaire et Conjugaison » (dépôt `chadracklonde/dictionnaire-francais`).
- **Auteur / éditeur** : Chadrack Londe, Kindu (RDC).
- **Dépôt** : `chadracklonde/dictionnaire-anglais-francais` (public), branche `main`.
- **Identifiant Android (définitif, ne jamais changer)** : `com.chadracklonde.dicoenfr`
- **But** : dictionnaire anglais ↔ français **100 % hors ligne**, grand public, issu du Wiktionnaire
  (CC BY-SA 4.0). Plateformes visées : Android (Play Store), Windows, macOS.
- **Technologie visée** : Flutter (Dart), base SQLite avec FTS5, compilation par GitHub Actions
  (aucun SDK Flutter local). Les scripts de données sont en Python.
- Cahier des charges complet (document éditable de Chadrack) : https://claude.ai/artifact/XhFm8df9jMQ2pHZi7yfFme

## 2. Décisions prises

1. **Application séparée**, avec son propre identifiant, sa fiche Play Store et sa signature.
2. **Sources fusionnées** : Wiktionnaire anglais (entrées, sens, traductions vers le français, formes,
   audio) + Wiktionnaire français (traductions inversées, enrichissement FR → EN).
3. **Fiche** : équivalents français en avant, définition anglaise en appui et repliable.
4. **Conjugaison anglaise gardée** : écran dédié ; formes simples du Wiktionnaire, temps composés
   produits par règles (petit moteur à écrire et à tester).
5. **Audio gardé** : enregistrements du Wiktionnaire (Wikimedia Commons) utilisables hors ligne,
   synthèse vocale du téléphone en repli. Auteur et licence de chaque fichier à conserver et afficher.
   Livraison par **Play Asset Delivery** (voir §7) : « hors ligne » signifie ici hors ligne après un
   premier téléchargement facultatif du pack audio, fait par Google Play.
6. Hors ligne total : aucune connexion réseau dans l'application, aucun compte, aucune publicité,
   aucune statistique. Toute fonction qui enverrait des données oblige à mettre à jour la politique de
   confidentialité **avant** publication.
7. **Une seule compilation CI par lot de modifications**.
8. **Accessibilité** : tout texte respecte WCAG AA (contraste 4,5:1 minimum), thème clair et sombre.
9. Interface en français, ton simple. Identité : même charte rouge/or/bleu, logo distinct.

## 3. Disposition du dépôt (état actuel)

```
.github/workflows/analyse.yml   Phase 0 : inventaire, analyse, rapport, release « analyse-phase0 »
tools/analyse_wiktionnaire.py   Lit un JSONL kaikki sur stdin, produit stats, paires, échantillons
tools/rapport_phase0.py         Fusion des paires, poids de l'audio, rapport (annotation RAPPORT-PHASE0)
tools/couverture_frequence.py   Couverture du vocabulaire courant via wordfreq (annotation COUVERTURE-FREQUENCE)
tools/sample_en.jsonl, sample_fr.jsonl   Jeux d'essai
tools/schema.sql, construire_base.py, liste_frequence.py, data/contractions.tsv   Phase 1 : base SQLite
.github/workflows/data.yml      Phase 1 : construit et publie la base (release « base-donnees »)
tools/test_analyse.py, test_base.py, test_requetes.py   Tests (python3 -I -m unittest discover -s tools -p "test_*.py")
engine/                         Phase 2 : moteur en Dart pur (lib/src : normalisation, requetes, source, source_sql, regles, moteur, conjugaison ; test/)
.github/workflows/engine.yml    Phase 2 : dart pub get, dart analyze, dart test
app/                            Phase 3 : application Flutter (lib/ theme, app, data/, screens/, widgets/ ; assets/icon ; icons_config/)
.github/workflows/build.yml     Phase 3 : tests + APK/AAB + Windows + macOS (déclenchement manuel)
tools/build_assets.py           Découpe la base en morceaux pour l'application (+ test_assets.py, test_contrastes.py)
CLAUDE.md, README.md, .gitignore
```
À venir selon le plan : politique de confidentialité (`CONFIDENTIALITE.md`).

## 4. Plan par phases

| Phase | Contenu | Critère d'acceptation |
| --- | --- | --- |
| 0. Analyse | Mesurer raw-wiktextract-data et fr-extract : couverture, fusion, audio, poids | **Faite le 2 novembre 2026** (§9) ; chiffres à valider par Chadrack |
| 1. Données | Schéma, import, traductions inversées, fusion, rapport qualité, release de la base | Rapport sans anomalie bloquante |
| 2. Moteur | Requêtes EN→FR / FR→EN, formes fléchies, suggestions, conjugaison anglaise par règles | Tests verts |
| 3. Application | Accueil, recherche, fiche bilingue, conjugaison, index, favoris, réglages | `flutter analyze` propre, essai sur téléphone |
| 4. Finitions | Tutoriel, À propos et licences, accessibilité, Windows et macOS | Contrastes ≥ 4,5:1, mention CC BY-SA |
| 5. Publication | Fiche Play Store, confidentialité, signature, AAB | Google accepte l'AAB (sinon Play Asset Delivery) |

## 5. Phase 0 — mode d'emploi

1. Actions → « Phase 0 - Analyser les sources » → Run workflow. Essai rapide : `limit` = `1000000`.
2. Le workflow vérifie d'abord que les deux URL répondent (annotations `INVENTAIRE`, `INVENTAIRE-LIENS`,
   `ANALYSE-0 source introuvable`). Sources (contrôlées par la CI le 2 novembre 2026) :
   - français : `https://kaikki.org/dictionary/downloads/fr/fr-extract.jsonl.gz` (≈ 737 Mo compressé) ;
   - anglais : `https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz` (toutes langues, filtré par
     le script sur `lang_code = en`). **`downloads/en/en-extract.jsonl.gz` n'existe pas (404)** : les
     fichiers `downloads/XX/XX-extract` ne couvrent que les éditions non anglaises.
   - le format réel des traductions (`lang_code` ou `code`) n'est pas vérifié ; le script accepte les deux.
   - un essai à `limit` fixe lit le début du fichier, où les entrées anglaises sont mélangées aux autres
     langues : ses chiffres valident le circuit, pas la couverture.
3. Le rapport sort en annotation `RAPPORT-PHASE0` et dans la release `analyse-phase0`
   (`rapport_phase0.md/json`, statistiques, échantillons, paires de traductions).
4. Lire le rapport, décider des seuils de qualité, finaliser le schéma (phase 1).

À mesurer et décider ensuite : couverture des traductions par sens, mots anglais gagnés par la fusion,
part des mots avec audio (US / UK), poids total de l'audio, formes verbales irrégulières disponibles,
et si le Play Asset Delivery est nécessaire.

## 6. Contraintes de l'environnement Claude (Claude Code sur le web)

- Pas de SDK Flutter ni de `pub.dev` : **le Dart n'est jamais compilé localement**. Validation par la CI
  (`flutter analyze` + build). Relire imports et types avant de pousser. Le Python, lui, se teste ici.
- Pas d'accès à kaikki.org ni à Wikimedia Commons depuis la session (proxy, erreur 403) : tout
  téléchargement de données passe par la CI. Ne pas contourner le blocage.
- L'API GraphQL de GitHub est bloquée : lancer un workflow par l'API REST :
  `gh api -X POST repos/chadracklonde/dictionnaire-anglais-francais/actions/workflows/analyse.yml/dispatches -f ref=main`
- L'API des secrets et de GitHub Pages est bloquée : ces réglages se font à la main dans l'interface.
- Les journaux de jobs ne sont pas téléchargeables : lire les **annotations**
  (`gh api repos/chadracklonde/dictionnaire-anglais-francais/check-runs/<id>/annotations`).
- Attendre la fin d'une compilation : interroger `actions/runs/<id>` jusqu'à `status=completed`,
  puis `actions/runs/<id>/jobs`.

## 7. Publication (à faire en phase 5)

- Code de version dans `app/pubspec.yaml` : à augmenter à chaque publication (Google refuse un code déjà utilisé).
- **Signature Android** : une clé propre à cette application reste à créer par Chadrack. Le fichier `.jks`
  et son mot de passe ne vont **jamais** dans le dépôt ; sauvegarde en deux endroits. Secrets GitHub
  d'Actions prévus : `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, à ajouter à la
  main dans Settings → Secrets and variables → Actions.
- La politique de confidentialité (même principe que le dictionnaire actuel : rien n'est collecté) sera
  servie par un fichier `CONFIDENTIALITE.md` dont l'URL GitHub est donnée à Google Play.
- Taille : le module principal doit rester sous 200 Mo. **Décidé : l'audio est livré par Play Asset Delivery** :
  l'audio des mots les plus courants arrive avec l'application, le reste forme un « pack prononciation »
  facultatif téléchargé une fois depuis Google Play (de préférence en Wi-Fi, avec barre de progression) ;
  la synthèse vocale du téléphone sert de repli si le pack manque (l'utilisateur peut le supprimer, et il
  peut être brièvement indisponible après une mise à jour). À fixer après la phase 0 : le découpage
  (fréquence, accent US/UK) et les limites de taille de
  https://support.google.com/googleplay/android-developer/answer/9859372#size_limits (non lues à ce jour).
  À vérifier : si ce mode exige la permission Internet dans l'application (impact sur la politique de
  confidentialité). Windows et macOS ne sont pas couverts par Play Asset Delivery : autre solution à prévoir.
  Le code Flutter qui demande et suit ces téléchargements ne se compile pas ici : validation par la CI et par
  des essais sur téléphone.

## 8. Modèle de message pour redémarrer

> Je reprends mon application « Dictionnaire Anglais-Français » (dépôt chadracklonde/dictionnaire-anglais-francais).
> Lis `CLAUDE.md` au complet. Je voudrais : [décrire la modification]. Regroupe les changements et ne
> lance la CI qu'une seule fois à la fin. Vérifie les contrastes WCAG AA si tu touches aux couleurs.
> Augmente le code de version dans `pubspec.yaml` si c'est pour une nouvelle publication.

## 9. Résultats de la phase 0 (2 novembre 2026)

Fichiers entiers ; détail dans la release `analyse-phase0` (rapport, statistiques, paires, entrées).

- **Édition anglaise** : 1 499 161 entrées anglaises (≈ 694 000 formes fléchies) ; 71 686 mots avec traduction
  française (128 993 traductions, toutes rattachées à un sens).
- **Édition française** : 129 366 entrées françaises avec traduction anglaise (196 130 traductions, 25,7 % seulement
  rattachées à un sens) ; **194 290 entrées anglaises définies en français**.
- **Fusion** : 248 266 couples, 161 904 mots anglais et 159 407 mots français couverts ; l'édition française
  apporte 90 218 mots anglais de plus que l'édition anglaise seule.
- **Vocabulaire courant** (liste wordfreq, formes ramenées au mot de base) : équivalent français pour 98,6 % des
  1 000 et des 5 000 premiers mots, 96,9 % des 10 000, 92,8 % des 20 000 (87,6 % avec l'édition anglaise seule).
  Les manques courants : contractions (can't, didn't…), possessifs (world's…), noms propres → règles de
  l'application + petite table écrite à la main. Non mesuré : couverture de tous les sens d'un mot polysémique.
- **Audio** : 129 612 entrées, 102 627 fichiers distincts, ≈ 17 Ko chacun → **≈ 1,7 Go** (149 mesures).
  Balises d'accent par enregistrement : US 58 584, Southern-England 45 322, Australia 22 917,
  General-American 7 039, UK 5 419. **Le compteur « audio UK » du rapport est faux** (il ne reconnaît pas
  Southern-England) : l'audio britannique est abondant. À corriger dans `US_TAGS` / `UK_TAGS` en phase 1.
- **Verbes** : 223 010 entrées verbe ; formes (passé et participe) disponibles pour 59 026 : à croiser avec les
  verbes de base avant de dimensionner le moteur de conjugaison.
- Le téléchargement et l'analyse des deux fichiers complets prennent environ 7 minutes dans la CI.

À décider avec Chadrack : un ou deux accents dans le pack audio ; gestion des contractions et possessifs ;
seuils de qualité pour le rapport de la phase 1.

## 10. Phase 1 — base de données (2 novembre 2026)

Construite par `data.yml` (≈ 15-30 min), publiée en `dictionnaire-en-fr.db.gz` dans la release `base-donnees`
avec `rapport_base.md/json`. Ordre : `lire --edition en`, `lire --edition fr`, `finaliser`, `rapport`.
Choix : accent US d'abord pour l'audio ; contractions par table à la main (64 lignes) ; possessif 's par règle
de l'application (phase 2) ; un mot sans équivalent ni définition française n'est gardé que si son rang de
fréquence est ≤ 30 000 (`seuil_rang`) ; accents corrigés (Southern-England = britannique).

Résultat : 188 Mo non compressé ; 213 721 mots, 174 049 avec équivalent français, 253 952 traductions
(en 67 226, en+fr 49 914, fr 136 812), 211 291 renvois « forme de », 93 320 fichiers audio (us 33 771,
uk 28 019, au 9 799, autre 22 534). Couverture des mots courants : 99,6 % (1000), 98,8 % (5000),
96,9 % (10 000), 92,7 % (20 000). Aucune anomalie bloquante.

À traiter en phase 2 : formes courantes sans équivalent (could, looking, turned, teeth, installed, women's…)
→ vérifier les renvois et les verbes sans formes (13 715 sur 22 411 verbes ont des formes) ; possessifs ;
noms propres ; 64 traductions de plus de 60 caractères ; auteur et licence de chaque audio (API Commons).

## 11. Phase 2 — moteur (2 novembre 2026)

**Données** (`construire_base.py`, `finaliser`) : nouveaux renvois « forme → mot de base » déduits des formes
listées par le mot de base (turned → turn, teeth → tooth : +22 665 sur la base d'essai) et, pour quatre cas,
des définitions (« conditional of can »). Sur la base de phase 1 cela porte la couverture à 100 % (1000),
98,9 % (5000), 96,8 % (10 000), 91,9 % (20 000) ; les manques restants sont surtout des noms propres et des
possessifs (règle du moteur). **La base doit être reconstruite** (`data.yml`) pour en profiter.

**Moteur** (`engine/`, Dart pur, sans Flutter) :
- `Source` (interface) + `SourceSql` : l'application fournit un `ExecuteurSql` (sqflite / sqlite3). Les
  requêtes SQL sont dans `requetes.dart` et **testées en Python contre une vraie base** (`test_requetes.py`,
  y compris l'usage d'index). Garder une constante `const String` par bloc de texte triple, sans dollar.
- `Moteur.chercher(texte)` cherche dans les deux sens : mot direct, formes fléchies de la base, contractions,
  possessifs (`'s`), formes régulières par règles (pluriels, -ed, -ing, comparatifs, -ly), pluriels et féminins
  français ; renvoie des fiches (EN→FR), des entrées inverses (FR→EN), la règle appliquée et des suggestions.
  Les formes conjuguées des verbes français ne sont pas dans la base : non couvertes.
- `Moteur.suggerer` (pendant la frappe, ≥ 2 caractères) et suggestions approchées quand rien n'est trouvé.
- `conjuguer` : formes de la base, table de ~140 verbes irréguliers (et composés : overcome, withdraw…),
  puis règles d'orthographe (doublement de la consonne, y → ied, -ie → -ying…) ; temps : présent, présent
  continu, prétérit, prétérit continu, présent parfait, plus-que-parfait, futur, futur antérieur, conditionnel
  présent et passé, impératif ; formes affirmative, négative, interrogative ; verbes à particule, be, modaux.
- Normalisation (`plier`, `normaliser`) : accord avec Python vérifié par `engine/test/pliage.tsv` (tests des
  deux côtés). Dart n'a pas de normalisation Unicode : table de lettres accentuées écrite à la main.

**Validation** : `engine.yml` (`dart analyze` + `dart test`) se déclenche à chaque push sous `engine/`. Le Dart
n'est jamais compilé ici : lire les annotations de cette CI et corriger avant d'aller plus loin.

## 12. Phase 3 — application Flutter (2 novembre 2026)

**Écrite, pas encore validée** : `build.yml` (Actions → « Phase 3 - Compiler l'application » → Run workflow) fait
tests Python + `dart analyze`/`dart test` du moteur, puis Android (APK + AAB, release `apk-dernier`), Windows, macOS.
Il télécharge `dictionnaire-en-fr.db.gz` de la release `base-donnees` : **relancer `data.yml` avant**, pour
que la base contienne les renvois de la phase 2. Lire les annotations (`ANALYSE …`) puis corriger.

- `flutter create --project-name dicoenfr` est refait à chaque compilation (dossiers `android/`, `windows/`,
  `macos/` non versionnés) ; le manifeste Android est patché (libellé, `<queries>` https + synthèse vocale).
  Aucune permission Internet. Signature : secrets `KEYSTORE_*` (sinon clé de débogage, non publiable).
- Base livrée en morceaux de 20 Mo (`assets/db/part_*`, produits par la CI, non versionnés) puis recopiée au
  premier lancement (`DbInstaller`), ouverte en lecture seule par sqflite FFI ; `ExecuteurSqflite` la relie au moteur.
- Écrans : accueil (recherche + suggestions + récents), résultat (onglets EN→FR / FR→EN), fiche (`FicheCard` :
  équivalents d'abord, définitions anglaises repliables), conjugaison (3 polarités, copie), index (lettres,
  pagination par curseur), favoris/récents, réglages (thème, taille, accent de la voix), à propos (CC BY-SA 4.0).
- Prononciation : synthèse vocale du téléphone (en-US / en-GB). Les enregistrements Wiktionnaire viendront en phase 5.
- Couleurs dans `lib/theme.dart` ; `tools/test_contrastes.py` vérifie 4,5:1 sur les paires texte/fond.
- **Logo provisoire** (livre « EN | FR ») : `app/assets/icon/`, à remplacer par un logo définitif.
- Reste pour la phase 4 : tutoriel, accessibilité (lecteur d'écran), mise en page large (Windows/macOS), notes.
