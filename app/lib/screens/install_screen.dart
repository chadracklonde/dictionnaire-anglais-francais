import 'package:flutter/material.dart';

import '../data/format.dart';
import '../theme.dart';

/// Écran de démarrage : préparation de la base (copie unique au premier lancement).
class InstallScreen extends StatelessWidget {
  const InstallScreen({
    super.key,
    required this.progression,
    required this.erreur,
    required this.onRetry,
    this.mots,
  });

  final double progression;
  final String? erreur;
  final VoidCallback onRetry;
  final int? mots;

  /// Arrondi au millier inférieur : jamais surévalué.
  static int _millier(int n) => n >= 1000 ? n ~/ 1000 * 1000 : n;

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final largeurLivre = (taille.shortestSide * 0.6).clamp(160.0, 300.0);
    const blanc = Colors.white;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF71918), Color(0xFF4A0010)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icon/book.png', width: largeurLivre),
                    const SizedBox(height: 28),
                    const Text(
                      'Anglais',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: blanc, fontSize: 36, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    const Text(
                      'Français',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Couleurs.or, fontSize: 36, fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const SizedBox(height: 28),
                    _Atout(
                      icone: Icons.manage_search_rounded,
                      texte: mots != null
                          ? '${formatCount(_millier(mots!))} mots anglais'
                          : 'Des centaines de milliers de mots',
                    ),
                    const SizedBox(height: 12),
                    const _Atout(icone: Icons.translate_rounded, texte: 'Anglais ↔ français'),
                    const SizedBox(height: 12),
                    const _Atout(icone: Icons.cloud_off_rounded, texte: '100 % hors ligne'),
                    const SizedBox(height: 36),
                    if (erreur == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: progression == 0 ? null : progression,
                              color: blanc,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            progression == 0 || progression >= 1
                                ? 'Chargement…'
                                : 'Préparation… ${(progression * 100).round()} %',
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                      if (progression > 0 && progression < 1) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Une seule fois, sans Internet.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'Impossible de préparer le dictionnaire.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: blanc, fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        erreur!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: blanc,
                          foregroundColor: const Color(0xFF8A0010),
                        ),
                        onPressed: onRetry,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Atout extends StatelessWidget {
  const _Atout({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icone, color: Colors.white70, size: 28),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            texte,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.2),
          ),
        ),
      ],
    );
  }
}
