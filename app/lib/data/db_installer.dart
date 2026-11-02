import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copie la base SQLite livrée en morceaux (assets/db/part_000, part_001…)
/// vers le dossier de l'application, une seule fois par version.
class DbInstaller {
  static Future<String> dbPath() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, 'dictionnaire-en-fr.db');
  }

  static Future<Map<String, dynamic>> manifest() async => json.decode(
        await rootBundle.loadString('assets/db/manifest.json'),
      ) as Map<String, dynamic>;

  /// Émet la progression de 0.0 à 1.0 ; termine tout de suite si la bonne version est installée.
  static Stream<double> install() async* {
    final manifest = await DbInstaller.manifest();
    final parts = manifest['parts'] as int;
    final version = manifest['version'] as String;

    final path = await dbPath();
    final dbFile = File(path);
    final versionFile = File('$path.version');

    if (await dbFile.exists() &&
        await versionFile.exists() &&
        (await versionFile.readAsString()).trim() == version) {
      yield 1.0;
      return;
    }

    final tmp = File('$path.tmp');
    if (await tmp.exists()) await tmp.delete();
    final sink = tmp.openWrite();
    try {
      yield 0.0;
      for (var i = 0; i < parts; i++) {
        final name = 'assets/db/part_${i.toString().padLeft(3, '0')}';
        final data = await rootBundle.load(name);
        sink.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        await sink.flush();
        yield (i + 1) / parts;
      }
    } finally {
      await sink.close();
    }

    if (await dbFile.exists()) await dbFile.delete();
    await tmp.rename(path);
    await versionFile.writeAsString(version);
  }
}
