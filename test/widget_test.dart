import 'package:flutter_test/flutter_test.dart';

import 'package:sqlite_devtool/src/models.dart';

void main() {
  test('DbSchema parses tables, columns, and foreign keys', () {
    final schema = DbSchema.fromJson({
      'schema': [
        {
          'name': 'orders',
          'rowCount': 12,
          'columns': [
            {'name': 'id', 'type': 'INTEGER', 'pk': 1, 'notNull': 1},
            {'name': 'user_id', 'type': 'INTEGER', 'pk': 0, 'notNull': 1},
          ],
          'foreignKeys': [
            {'column': 'user_id', 'refTable': 'users', 'refColumn': 'id'},
          ],
        },
        {
          'name': 'users',
          'rowCount': 5,
          'columns': [
            {'name': 'id', 'type': 'INTEGER', 'pk': 1, 'notNull': 1},
            {'name': 'name', 'type': 'TEXT', 'pk': 0, 'notNull': 0},
          ],
          'foreignKeys': [],
        },
      ],
    });

    expect(schema.tables, hasLength(2));
    final orders = schema.table('orders')!;
    expect(orders.rowCount, 12);
    expect(orders.columns.first.isPrimaryKey, isTrue);
    expect(orders.foreignKeys.single.refTable, 'users');
    expect(orders.foreignKeys.single.refColumn, 'id');
    expect(schema.table('missing'), isNull);
  });

  test('DbSchema tolerates malformed payloads', () {
    expect(DbSchema.fromJson({}).tables, isEmpty);
    expect(DbSchema.fromJson({'schema': 'nonsense'}).tables, isEmpty);
    final partial = DbSchema.fromJson({
      'schema': [
        {'name': 'bare'},
      ],
    });
    expect(partial.tables.single.name, 'bare');
    expect(partial.tables.single.rowCount, -1);
    expect(partial.tables.single.columns, isEmpty);
  });
}
