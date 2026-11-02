import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/user_store.dart';
import '../widgets/fiche_card.dart';

/// Une seule fiche, ouverte à partir des favoris, de l'historique ou d'une liste.
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.mot});

  final Mot mot;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  Future<Fiche>? _fiche;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fiche == null) {
      final services = AppScope.of(context);
      // Après la construction : modifier l'historique relance l'arbre de widgets.
      Future<void>.microtask(() =>
          services.user.ajouterHistorique(UserStore.cle(widget.mot.mot, widget.mot.nature)));
      _fiche = services.moteur.fiche(widget.mot);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mot.mot)),
      body: FutureBuilder<Fiche>(
        future: _fiche,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [FicheCard(fiche: snap.data!)],
          );
        },
      ),
    );
  }
}
