import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Largeur maximale du contenu : sur grand écran (Windows, macOS, tablette) les listes
/// restent centrées et lisibles au lieu de s'étirer sur toute la fenêtre.
const double largeurMaxContenu = 840;

/// Marges d'une liste : 16 px sur téléphone, davantage sur grand écran.
EdgeInsets padPage(BuildContext context, {double v = 16}) {
  final largeur = MediaQuery.sizeOf(context).width;
  final h = math.max(16.0, (largeur - largeurMaxContenu) / 2);
  return EdgeInsets.symmetric(horizontal: h, vertical: v);
}

/// Les marges de [padPage] se calculent d'après la largeur de l'écran ; dans un volet ou à côté
/// d'une barre latérale, c'est la largeur réelle de la zone qui compte.
class AvecLargeurLocale extends StatelessWidget {
  const AvecLargeurLocale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final donnees = MediaQuery.of(context);
        return MediaQuery(
          data: donnees.copyWith(size: Size(c.maxWidth, donnees.size.height)),
          child: child,
        );
      },
    );
  }
}

/// Largeur à partir de laquelle une liste s'affiche avec le détail à côté (Windows, macOS, tablette).
const double largeurDeuxVolets = 720;

/// La liste à gauche, le détail à droite ; un message invite à choisir quand rien n'est ouvert.
class DeuxVolets extends StatelessWidget {
  const DeuxVolets({super.key, required this.liste, required this.detail});

  final Widget liste;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 360, child: AvecLargeurLocale(child: liste)),
        const VerticalDivider(width: 1),
        Expanded(
          child: AvecLargeurLocale(
            child: detail ??
                Center(
                  child: Text(
                    'Choisissez un mot dans la liste.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
