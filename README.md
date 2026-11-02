# Dictionnaire Anglais-Français

Dictionnaire anglais ↔ français, **100 % hors ligne**, construit à partir du Wiktionnaire
(licence CC BY-SA 4.0). Application Android, Windows et macOS, compilée par GitHub Actions.

- **Auteur** : Chadrack Londe, Kindu (RDC)
- **Identifiant Android (définitif)** : `com.chadracklonde.dicoenfr`
- **Contenu** : définitions, équivalents par sens, conjugaison anglaise, audio de prononciation
- **Aucune** connexion réseau, aucun compte, aucune publicité, aucune statistique

## État du projet

Phase 0 en cours : analyse des deux extractions du Wiktionnaire (anglais et français) pour
mesurer la couverture des traductions, le recouvrement entre sources et le poids de l'audio.
Le détail est dans `CLAUDE.md`.

## Lancer la phase 0

Onglet **Actions** → « Phase 0 - Analyser les sources » → *Run workflow*.
Pour un essai rapide, renseigner `limit` (par exemple `200000`). Le rapport apparaît en annotation
`RAPPORT-PHASE0` et dans la release `analyse-phase0`.

## Tests

```
python3 -I -m unittest discover -s tools -p "test_*.py"
```

## Licence et sources

Le contenu dérivé du Wiktionnaire reste sous licence **CC BY-SA 4.0**. Les enregistrements audio
viennent de Wikimedia Commons, avec des licences propres à chaque fichier : l'auteur et la licence
de chacun seront conservés et affichés dans l'application.
