import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite par FFI sur toutes les plateformes : même moteur partout
  // (bibliothèques natives fournies par sqlite3_flutter_libs).
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const DictionnaireApp());
}
