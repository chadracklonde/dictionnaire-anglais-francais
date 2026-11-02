import 'dart:ui' show PointerDeviceKind;

import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/db_installer.dart';
import 'data/executeur_sqflite.dart';
import 'data/user_store.dart';
import 'screens/home_screen.dart';
import 'screens/install_screen.dart';
import 'theme.dart';

/// Version affichée dans « À propos » (à garder alignée sur pubspec.yaml).
const String appVersion = '0.2.0';

/// Services partagés par tous les écrans.
class AppServices {
  AppServices({required this.moteur, required this.source, required this.user});

  final Moteur moteur;
  final SourceSql source;
  final UserStore user;

  /// Retrouve un mot à partir de sa clé « mot<TAB>nature ».
  Future<Mot?> resoudre(String cle) async {
    final (mot, nature) = UserStore.decouper(cle);
    final trouves = await source.motsParRecherche(plier(mot));
    for (final m in trouves) {
      if (m.mot == mot && m.nature == nature) return m;
    }
    for (final m in trouves) {
      if (m.nature == nature) return m;
    }
    return trouves.isEmpty ? null : trouves.first;
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope introuvable dans l\'arbre de widgets');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

class DictionnaireApp extends StatefulWidget {
  const DictionnaireApp({super.key});

  @override
  State<DictionnaireApp> createState() => _DictionnaireAppState();
}

class _DictionnaireAppState extends State<DictionnaireApp> {
  double _progression = 0;
  String? _erreur;
  AppServices? _services;
  int? _mots;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    if (_erreur != null) setState(() => _erreur = null);
    try {
      final manifest = await DbInstaller.manifest();
      if (mounted) setState(() => _mots = manifest['words'] as int?);
      await for (final p in DbInstaller.install()) {
        if (!mounted) return;
        setState(() => _progression = p);
      }
      final db = await databaseFactory.openDatabase(
        await DbInstaller.dbPath(),
        options: OpenDatabaseOptions(readOnly: true),
      );
      final source = SourceSql(ExecuteurSqflite(db));
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _services = AppServices(
          moteur: Moteur(source),
          source: source,
          user: UserStore(prefs),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = '$e');
    }
  }

  static ThemeMode _mode(String valeur) => switch (valeur) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Widget _application(AppServices? services) {
    final user = services?.user;
    return MaterialApp(
      title: 'Dictionnaire Anglais-Français',
      debugShowCheckedModeBanner: false,
      theme: construireTheme(Brightness.light),
      darkTheme: construireTheme(Brightness.dark),
      themeMode: _mode(user?.themeMode ?? 'system'),
      builder: (context, child) {
        final systeme = MediaQuery.textScalerOf(context).scale(1.0);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(systeme * (user?.textScale ?? 1.0)),
          ),
          // Défilement à la souris et au doigt (Windows, macOS : listes de lettres, onglets).
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: PointerDeviceKind.values.toSet(),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: services == null
          ? InstallScreen(
              progression: _progression,
              erreur: _erreur,
              onRetry: _demarrer,
              mots: _mots,
            )
          : const HomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services == null) return _application(null);
    return ListenableBuilder(
      listenable: services.user,
      builder: (context, _) => AppScope(services: services, child: _application(services)),
    );
  }
}
