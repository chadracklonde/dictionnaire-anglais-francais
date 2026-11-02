import 'package:dicoenfr_engine/dicoenfr_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Relie le moteur à une base ouverte par sqflite.
class ExecuteurSqflite implements ExecuteurSql {
  ExecuteurSqflite(this._db);

  final Database _db;

  @override
  Future<List<Map<String, Object?>>> requete(String sql, [List<Object?> arguments = const []]) {
    return _db.rawQuery(sql, arguments);
  }
}
