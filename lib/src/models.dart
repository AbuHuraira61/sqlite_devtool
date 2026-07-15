/// Schema returned by `ext.sqlite_inspector.getSchema`.
class DbSchema {
  const DbSchema({required this.tables});

  final List<TableSchema> tables;

  factory DbSchema.fromJson(Map<String, dynamic> json) {
    final raw = json['schema'];
    return DbSchema(
      tables: [
        if (raw is List)
          for (final table in raw)
            if (table is Map<String, dynamic>) TableSchema.fromJson(table),
      ],
    );
  }

  TableSchema? table(String name) {
    for (final table in tables) {
      if (table.name == name) return table;
    }
    return null;
  }
}

class TableSchema {
  const TableSchema({
    required this.name,
    required this.rowCount,
    required this.columns,
    required this.foreignKeys,
  });

  final String name;

  /// -1 when unknown (older host package or count failure).
  final int rowCount;
  final List<ColumnSchema> columns;
  final List<ForeignKeyRef> foreignKeys;

  factory TableSchema.fromJson(Map<String, dynamic> json) {
    final columns = json['columns'];
    final foreignKeys = json['foreignKeys'];
    return TableSchema(
      name: json['name']?.toString() ?? '',
      rowCount: (json['rowCount'] as num?)?.toInt() ?? -1,
      columns: [
        if (columns is List)
          for (final column in columns)
            if (column is Map<String, dynamic>) ColumnSchema.fromJson(column),
      ],
      foreignKeys: [
        if (foreignKeys is List)
          for (final fk in foreignKeys)
            if (fk is Map<String, dynamic>) ForeignKeyRef.fromJson(fk),
      ],
    );
  }
}

class ColumnSchema {
  const ColumnSchema({
    required this.name,
    required this.type,
    required this.isPrimaryKey,
    required this.notNull,
  });

  final String name;
  final String type;
  final bool isPrimaryKey;
  final bool notNull;

  factory ColumnSchema.fromJson(Map<String, dynamic> json) {
    return ColumnSchema(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isPrimaryKey: (json['pk'] as num? ?? 0) != 0,
      notNull: (json['notNull'] as num? ?? 0) != 0,
    );
  }
}

class ForeignKeyRef {
  const ForeignKeyRef({
    required this.column,
    required this.refTable,
    required this.refColumn,
  });

  final String column;
  final String refTable;

  /// Null when the foreign key references the target's implicit primary key.
  final String? refColumn;

  factory ForeignKeyRef.fromJson(Map<String, dynamic> json) {
    return ForeignKeyRef(
      column: json['column']?.toString() ?? '',
      refTable: json['refTable']?.toString() ?? '',
      refColumn: json['refColumn']?.toString(),
    );
  }
}
