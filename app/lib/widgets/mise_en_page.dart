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
