import 'dart:convert';
import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';

/// Registers the `ext.sqlite_inspector.*` service extensions that the
/// SQLite Inspector DevTools extension calls.
///
/// Call [SqliteInspector.register] once from the main isolate after opening
/// your database:
///
/// ```dart
/// final db = await openDatabase('app.db');
/// SqliteInspector.register(db);
/// ```
///
/// Service extensions only exist in debug and profile builds, so this is a
/// no-op in release builds as far as DevTools is concerned.
class SqliteInspector {
  SqliteInspector._();

  static Database? _db;
  static bool _registered = false;

  /// Registers (or re-points) the inspector at [db].
  ///
  /// Safe to call multiple times, e.g. if you close and reopen the database;
  /// the service extensions are only registered once.
  static void register(Database db) {
    _db = db;
    if (_registered) return;
    _registered = true;

    developer.registerExtension('ext.sqlite_inspector.getTables',
        (method, params) async {
      try {
        final db = _requireDb();
        final rows = await db.rawQuery(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
          "ORDER BY name",
        );
        return _ok({
          'tables': [for (final row in rows) row['name'] as String],
        });
      } catch (e) {
        return _error(e);
      }
    });

    developer.registerExtension('ext.sqlite_inspector.executeQuery',
        (method, params) async {
      try {
        final db = _requireDb();
        final query = (params['query'] ?? '').trim();
        if (query.isEmpty) {
          return _error('No query provided.');
        }
        final upper = query.toUpperCase();
        final isReadQuery = upper.startsWith('SELECT') ||
            upper.startsWith('PRAGMA') ||
            upper.startsWith('EXPLAIN') ||
            upper.startsWith('WITH');
        if (isReadQuery) {
          final rows = await db.rawQuery(query);
          return _ok({
            'data': [for (final row in rows) _jsonSafe(row)],
          });
        }
        final count = await db.rawUpdate(query);
        return _ok({
          'data': [
            {'rows_affected': count},
          ],
        });
      } catch (e) {
        return _error(e);
      }
    });

    developer.registerExtension('ext.sqlite_inspector.getSchema',
        (method, params) async {
      try {
        final db = _requireDb();
        final tableRows = await db.rawQuery(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
          "ORDER BY name",
        );
        final tables = <Map<String, Object?>>[];
        for (final row in tableRows) {
          final name = row['name'] as String;
          final quoted = _quote(name);
          final columns = await db.rawQuery('PRAGMA table_info($quoted)');
          final foreignKeys =
              await db.rawQuery('PRAGMA foreign_key_list($quoted)');
          var rowCount = -1;
          try {
            final count = await db.rawQuery('SELECT COUNT(*) AS c FROM $quoted');
            rowCount = (count.first['c'] as num?)?.toInt() ?? -1;
          } catch (_) {
            // Row count is informational only; leave it unknown on failure.
          }
          tables.add({
            'name': name,
            'rowCount': rowCount,
            'columns': [
              for (final column in columns)
                {
                  'name': column['name'],
                  'type': column['type'],
                  'notNull': column['notnull'],
                  'pk': column['pk'],
                  'defaultValue': column['dflt_value']?.toString(),
                },
            ],
            'foreignKeys': [
              for (final fk in foreignKeys)
                {
                  'column': fk['from'],
                  'refTable': fk['table'],
                  'refColumn': fk['to'],
                  'onUpdate': fk['on_update'],
                  'onDelete': fk['on_delete'],
                },
            ],
          });
        }
        return _ok({'schema': tables});
      } catch (e) {
        return _error(e);
      }
    });
  }

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  static Database _requireDb() {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError(
        'No open database registered. Call SqliteInspector.register(db) '
        'after opening your database.',
      );
    }
    return db;
  }

  // The DevTools extension decodes response.json['result'] as a JSON string,
  // hence the nested jsonEncode.
  static developer.ServiceExtensionResponse _ok(Map<String, Object?> payload) {
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'result': jsonEncode(payload)}),
    );
  }

  static developer.ServiceExtensionResponse _error(Object error) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      error.toString(),
    );
  }

  // SQLite values can include BLOBs (Uint8List), which jsonEncode rejects.
  static Map<String, Object?> _jsonSafe(Map<String, Object?> row) {
    return {
      for (final entry in row.entries)
        entry.key: switch (entry.value) {
          null => null,
          num() || String() || bool() => entry.value,
          final other => other.toString(),
        },
    };
  }
}
