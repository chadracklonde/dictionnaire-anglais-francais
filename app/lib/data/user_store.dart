import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris, historique et réglages, enregistrés sur l'appareil.
/// Un mot est repéré par la clé « mot<TAB>nature » (voir [cle]).
class UserStore extends ChangeNotifier {
  UserStore(this._prefs)
      : favoris = List.of(_prefs.getStringList('favoris') ?? const []),
        historique = List.of(_prefs.getStringList('historique') ?? const []);

  static const int _historiqueMax = 100;

  final SharedPreferences _prefs;
  final List<String> favoris;
  final List<String> historique;

  static String cle(String mot, String nature) => '$mot\t$nature';

  /// Découpe une clé en (mot, nature).
  static (String, String) decouper(String cle) {
    final i = cle.indexOf('\t');
    return i < 0 ? (cle, '') : (cle.substring(0, i), cle.substring(i + 1));
  }

  String get themeMode => _prefs.getString('themeMode') ?? 'system';
  double get textScale => _prefs.getDouble('textScale') ?? 1.0;

  /// Accent de la voix : 'us' ou 'uk'.
  String get accent => _prefs.getString('accent') ?? 'us';

  Future<void> setThemeMode(String valeur) async {
    await _prefs.setString('themeMode', valeur);
    notifyListeners();
  }

  Future<void> setTextScale(double valeur) async {
    await _prefs.setDouble('textScale', valeur);
    notifyListeners();
  }

  Future<void> setAccent(String valeur) async {
    await _prefs.setString('accent', valeur);
    notifyListeners();
  }

  bool estFavori(String cle) => favoris.contains(cle);

  Future<void> basculerFavori(String cle) async {
    if (!favoris.remove(cle)) favoris.insert(0, cle);
    await _prefs.setStringList('favoris', favoris);
    notifyListeners();
  }

  Future<void> ajouterHistorique(String cle) async {
    historique.remove(cle);
    historique.insert(0, cle);
    if (historique.length > _historiqueMax) {
      historique.removeRange(_historiqueMax, historique.length);
    }
    await _prefs.setStringList('historique', historique);
    notifyListeners();
  }

  Future<void> viderHistorique() async {
    historique.clear();
    await _prefs.setStringList('historique', historique);
    notifyListeners();
  }
}
