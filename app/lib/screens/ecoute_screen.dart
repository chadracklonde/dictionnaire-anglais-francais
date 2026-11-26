import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/speech.dart';
import '../widgets/mise_en_page.dart';

/// Écouter une liste en boucle, sans regarder l'écran : le mot en anglais, une pause, puis son
/// équivalent en français. Pratique pour apprendre en marchant ou dans les transports.
class EcouteScreen extends StatefulWidget {
  const EcouteScreen({super.key, required this.titre, required this.cles});

  final String titre;
  final List<String> cles;

  @override
  State<EcouteScreen> createState() => _EcouteScreenState();
}

class _EcouteScreenState extends State<EcouteScreen> {
  bool _lecture = false;
  int _position = 0;
  Fiche? _fiche;
  int _passage = 0; // change à chaque démarrage ou arrêt : une lecture périmée s'interrompt seule
  bool _voixManquante = false;

  @override
  void dispose() {
    _passage++;
    speech.arreter();
    super.dispose();
  }

  Future<void> _demarrer() async {
    if (widget.cles.isEmpty) return;
    final mon = ++_passage;
    setState(() {
      _lecture = true;
      _voixManquante = false;
    });
    final services = AppScope.of(context);
    final langue = services.user.accent == 'uk' ? 'en-GB' : 'en-US';
    while (mounted && mon == _passage) {
      final cle = widget.cles[_position % widget.cles.length];
      final mot = await services.resoudre(cle);
      if (mot != null) {
        final fiche = await services.moteur.fiche(mot);
        if (!mounted || mon != _passage) return;
        setState(() => _fiche = fiche);
        final anglais = await speech.dire(fiche.mot.mot, langue);
        if (!mounted || mon != _passage) return;
        if (!anglais) {
          setState(() {
            _voixManquante = true;
            _lecture = false;
          });
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted || mon != _passage) return;
        if (fiche.equivalents.isNotEmpty) {
          await speech.dire(fiche.equivalents.first.fr, 'fr-FR');
        }
        if (!mounted || mon != _passage) return;
        await Future<void>.delayed(const Duration(milliseconds: 1400));
      }
      if (!mounted || mon != _passage) return;
      setState(() => _position++);
    }
  }

  Future<void> _arreter() async {
    _passage++;
    await speech.arreter();
    if (mounted) setState(() => _lecture = false);
  }

  Future<void> _aller(int pas) async {
    final etait = _lecture;
    await _arreter();
    if (widget.cles.isEmpty) return;
    setState(() => _position = (_position + pas) % widget.cles.length);
    if (etait) await _demarrer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fiche = _fiche;
    return Scaffold(
      appBar: AppBar(title: Text('Écouter · ${widget.titre}')),
      body: ListView(
        padding: padPage(context, v: 24),
        children: [
          Text(
            widget.cles.isEmpty
                ? 'Cette liste est vide.'
                : '${widget.cles.length} mot(s). Chaque mot est dit en anglais, puis son équivalent en français, '
                    'en boucle. L\'écran peut rester éteint.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (fiche != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(fiche.mot.mot,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text(
              fiche.equivalents.isEmpty ? '' : fiche.equivalents.first.fr,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                tooltip: 'Mot précédent',
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: widget.cles.isEmpty ? null : () => _aller(-1),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: Icon(_lecture ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_lecture ? 'Pause' : 'Lecture'),
                onPressed: widget.cles.isEmpty ? null : (_lecture ? _arreter : _demarrer),
              ),
              const SizedBox(width: 16),
              IconButton.outlined(
                tooltip: 'Mot suivant',
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: widget.cles.isEmpty ? null : () => _aller(1),
              ),
            ],
          ),
          if (_voixManquante) ...[
            const SizedBox(height: 16),
            Text(
              'Aucune voix anglaise n\'est installée sur cet appareil.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
