import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';

import 'models.dart';

class QueryResult {
  const QueryResult({required this.rows, required this.elapsed});

  final List<Map<String, dynamic>> rows;
  final Duration elapsed;
}

/// Talks to the `ext.sqlite_inspector.*` service extensions registered by the
/// sqlite_inspector package inside the connected app.
class InspectorService {
  Future<Map<String, dynamic>> _call(
    String method, {
    Map<String, String>? args,
  }) async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      method,
      args: args,
    );
    final result = response.json?['result'];
    final decoded = jsonDecode(result is String ? result : '{}');
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Fetches the full schema map. Falls back to bare table names when the
  /// connected app runs an older sqlite_inspector without `getSchema`.
  Future<DbSchema> fetchSchema() async {
    try {
      return DbSchema.fromJson(await _call('ext.sqlite_inspector.getSchema'));
    } catch (_) {
      final decoded = await _call('ext.sqlite_inspector.getTables');
      final names = decoded['tables'];
      return DbSchema(
        tables: [
          if (names is List)
            for (final name in names)
              TableSchema(
                name: name.toString(),
                rowCount: -1,
                columns: const [],
                foreignKeys: const [],
              ),
        ],
      );
    }
  }

  Future<QueryResult> executeQuery(String query) async {
    final stopwatch = Stopwatch()..start();
    final decoded = await _call(
      'ext.sqlite_devtool_api.executeQuery',
      args: {'query': query},
    );
    stopwatch.stop();
    final data = decoded['data'];
    return QueryResult(
      rows: [
        if (data is List)
          for (final row in data)
            if (row is Map<String, dynamic>) row,
      ],
      elapsed: stopwatch.elapsed,
    );
  }
}
}
