import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/menu_mot.dart';
import '../widgets/mise_en_page.dart';
import 'result_screen.dart';

/// Mots anglais qui correspondent à un motif : « inter* », « *tion », « c?t ».
class MotifScreen extends StatelessWidget {
  const MotifScreen({super.key, required this.motif});

  final String motif;

  @override
  Widget build(BuildContext context) {
    final moteur = AppScope.of(context).moteur;
    return Scaffold(
      appBar: AppBar(title: Text(motif)),
      body: FutureBuilder<List<String>>(
        future: moteur.chercherMotif(motif),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          final mots = snap.data;
          if (mots == null) return const Center(child: CircularProgressIndicator());
          if (mots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun mot ne correspond. « * » remplace plusieurs lettres, « ? » une seule. '
                  'Ajoutez au moins une lettre, par exemple « inter* » ou « c?t ».',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: padPage(context, v: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('${mots.length}${mots.length >= 100 ? ' premiers' : ''} mot(s)'),
              ),
              for (final m in mots)
                ListTile(
                  dense: true,
                  title: Text(m),
                  onLongPress: () => afficherMenuMot(context, m),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ResultScreen(requete: m)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
