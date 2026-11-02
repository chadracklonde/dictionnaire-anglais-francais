import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// Charte rouge / or / bleu. Chaque couleur de texte reste à 4,5:1 minimum
/// (WCAG AA) sur son fond, en clair comme en sombre (vérifié par
/// tools/test_contrastes.py, qui lit les constantes ci-dessous).
class Couleurs {
  Couleurs._();

  // Thème clair
  static const Color clairPrimaire = Color(0xFFA50E1A);
  static const Color clairSurPrimaire = Color(0xFFFFFFFF);
  static const Color clairSecondaire = Color(0xFF1C486F);
  static const Color clairSurSecondaire = Color(0xFFFFFFFF);
  static const Color clairTertiaire = Color(0xFF6F5000);
  static const Color clairSurface = Color(0xFFFFFBFF);
  static const Color clairTexte = Color(0xFF1B1B1F);
  static const Color clairTexteDiscret = Color(0xFF49454F);

  // Thème sombre
  static const Color sombrePrimaire = Color(0xFFFFB3AE);
  static const Color sombreSurPrimaire = Color(0xFF5F0010);
  static const Color sombreSecondaire = Color(0xFFA5C8F2);
  static const Color sombreSurSecondaire = Color(0xFF07304F);
  static const Color sombreTertiaire = Color(0xFFF2B632);
  static const Color sombreSurface = Color(0xFF121212);
  static const Color sombreTexte = Color(0xFFE6E1E5);
  static const Color sombreTexteDiscret = Color(0xFFCAC4D0);

  static const Color or = Color(0xFFF2B632);
}

ThemeData construireTheme(Brightness luminosite) {
  final sombre = luminosite == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFFAF0B18),
    brightness: luminosite,
  );
  final schema = sombre
      ? base.copyWith(
          primary: Couleurs.sombrePrimaire,
          onPrimary: Couleurs.sombreSurPrimaire,
          secondary: Couleurs.sombreSecondaire,
          onSecondary: Couleurs.sombreSurSecondaire,
          tertiary: Couleurs.sombreTertiaire,
          surface: Couleurs.sombreSurface,
          onSurface: Couleurs.sombreTexte,
          onSurfaceVariant: Couleurs.sombreTexteDiscret,
        )
      : base.copyWith(
          primary: Couleurs.clairPrimaire,
          onPrimary: Couleurs.clairSurPrimaire,
          secondary: Couleurs.clairSecondaire,
          onSecondary: Couleurs.clairSurSecondaire,
          tertiary: Couleurs.clairTertiaire,
          surface: Couleurs.clairSurface,
          onSurface: Couleurs.clairTexte,
          onSurfaceVariant: Couleurs.clairTexteDiscret,
        );
  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    appBarTheme: sombre
        ? null
        : const AppBarTheme(
            backgroundColor: Couleurs.clairPrimaire,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
  );
}
