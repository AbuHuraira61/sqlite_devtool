import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

const _cardWidth = 250.0;
const _headerHeight = 40.0;
const _rowHeight = 24.0;
const _footerHeight = 22.0;
const _bottomPad = 8.0;
const _maxColumnRows = 100;

double _cardHeight(TableSchema table) {
  final shown = math.min(table.columns.length, _maxColumnRows);
  final truncated = table.columns.length > _maxColumnRows;
  return _headerHeight +
      1 +
      shown * _rowHeight +
      (truncated ? _footerHeight : 0) +
      _bottomPad;
}

class _SchemaEdge {
  const _SchemaEdge({
    required this.from,
    required this.fromColumn,
    required this.to,
    required this.toColumn,
    required this.inferred,
  });

  final String from;
  final String fromColumn;
  final String to;
  final String? toColumn;

  /// True when there is no declared constraint and the link was inferred
  /// from a `<table>_id` naming convention.
  final bool inferred;
}

List<_SchemaEdge> _buildEdges(DbSchema schema) {
  final byLowerName = {
    for (final table in schema.tables) table.name.toLowerCase(): table.name,
  };
  final edges = <_SchemaEdge>[];
  for (final table in schema.tables) {
    final declared = <String>{};
    for (final fk in table.foreignKeys) {
      declared.add(fk.column);
      final target = byLowerName[fk.refTable.toLowerCase()];
      if (target == null) continue;
      edges.add(
        _SchemaEdge(
          from: table.name,
          fromColumn: fk.column,
          to: target,
          toColumn: fk.refColumn,
          inferred: false,
        ),
      );
    }
    // Undeclared but conventional links: a `user_id` column pointing at a
    // `user`/`users` table reads as a relationship even without a constraint.
    for (final column in table.columns) {
      final lower = column.name.toLowerCase();
      if (!lower.endsWith('_id') || declared.contains(column.name)) continue;
      final base = lower.substring(0, lower.length - 3);
      final candidates = [
        base,
        '${base}s',
        '${base}es',
        if (base.endsWith('y')) '${base.substring(0, base.length - 1)}ies',
      ];
      for (final candidate in candidates) {
        final target = byLowerName[candidate];
        if (target != null && target != table.name) {
          edges.add(
            _SchemaEdge(
              from: table.name,
              fromColumn: column.name,
              to: target,
              toColumn: null,
              inferred: true,
            ),
          );
          break;
        }
      }
    }
  }
  return edges;
}

/// Lays tables out on a grid, ordered by BFS from the most connected table so
/// related tables land near each other.
Map<String, Offset> _gridPositions(
  List<TableSchema> tables,
  List<_SchemaEdge> edges,
) {
  if (tables.isEmpty) return {};
  final degree = <String, int>{for (final t in tables) t.name: 0};
  final adjacency = <String, Set<String>>{
    for (final t in tables) t.name: <String>{},
  };
  for (final edge in edges) {
    degree[edge.from] = (degree[edge.from] ?? 0) + 1;
    degree[edge.to] = (degree[edge.to] ?? 0) + 1;
    adjacency[edge.from]?.add(edge.to);
    adjacency[edge.to]?.add(edge.from);
  }
  final seeds = [for (final t in tables) t.name]
    ..sort((a, b) => (degree[b] ?? 0).compareTo(degree[a] ?? 0));
  final ordered = <String>[];
  final visited = <String>{};
  for (final seed in seeds) {
    if (visited.contains(seed)) continue;
    final queue = <String>[seed];
    while (queue.isNotEmpty) {
      final name = queue.removeAt(0);
      if (!visited.add(name)) continue;
      ordered.add(name);
      final neighbors =
          (adjacency[name] ?? const <String>{})
              .where((n) => !visited.contains(n))
              .toList()
            ..sort((a, b) => (degree[b] ?? 0).compareTo(degree[a] ?? 0));
      queue.addAll(neighbors);
    }
  }
  final byName = {for (final t in tables) t.name: t};
  final columns = math.max(1, math.sqrt(ordered.length).ceil());
  const startX = 60.0, startY = 60.0, hGap = 130.0, vGap = 80.0;
  final positions = <String, Offset>{};
  var x = startX;
  var y = startY;
  var column = 0;
  var rowMaxHeight = 0.0;
  for (final name in ordered) {
    positions[name] = Offset(x, y);
    rowMaxHeight = math.max(rowMaxHeight, _cardHeight(byName[name]!));
    column++;
    if (column >= columns) {
      column = 0;
      x = startX;
      y += rowMaxHeight + vGap;
      rowMaxHeight = 0;
    } else {
      x += _cardWidth + hGap;
    }
  }
  return positions;
}

/// Interactive map of the database: one card per table, connected by its
/// foreign-key relationships.
class SchemaMapView extends StatefulWidget {
  const SchemaMapView({
    super.key,
    required this.schema,
    required this.onOpenTable,
  });

  final DbSchema schema;
  final void Function(String tableName) onOpenTable;

  @override
  State<SchemaMapView> createState() => _SchemaMapViewState();
}

class _SchemaMapViewState extends State<SchemaMapView> {
  final _viewController = TransformationController();
  late List<_SchemaEdge> _edges;
  late Map<String, Offset> _positions;
  String? _focused;

  @override
  void initState() {
    super.initState();
    _edges = _buildEdges(widget.schema);
    _positions = _gridPositions(widget.schema.tables, _edges);
  }

  @override
  void didUpdateWidget(SchemaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.schema, widget.schema)) return;
    _edges = _buildEdges(widget.schema);
    final fresh = _gridPositions(widget.schema.tables, _edges);
    _positions = {
      for (final table in widget.schema.tables)
        table.name: _positions[table.name] ?? fresh[table.name]!,
    };
    if (_focused != null && widget.schema.table(_focused!) == null) {
      _focused = null;
    }
  }

  @override
  void dispose() {
    _viewController.dispose();
    super.dispose();
  }

  Set<String> _relatedTo(String name) {
    final related = {name};
    for (final edge in _edges) {
      if (edge.from == name) related.add(edge.to);
      if (edge.to == name) related.add(edge.from);
    }
    return related;
  }

  Size _canvasSize() {
    var maxX = 900.0, maxY = 700.0;
    for (final table in widget.schema.tables) {
      final position = _positions[table.name];
      if (position == null) continue;
      maxX = math.max(maxX, position.dx + _cardWidth);
      maxY = math.max(maxY, position.dy + _cardHeight(table));
    }
    return Size(maxX + 240, maxY + 240);
  }

  @override
  Widget build(BuildContext context) {
    final tables = widget.schema.tables;
    final related = _focused == null ? null : _relatedTo(_focused!);
    final canvas = _canvasSize();
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _viewController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(1200),
            minScale: 0.3,
            maxScale: 2.5,
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BlueprintPainter(
                        schema: widget.schema,
                        positions: Map.of(_positions),
                        edges: _edges,
                        focused: _focused,
                      ),
                    ),
                  ),
                  for (final table in tables)
                    if (_positions[table.name] != null)
                      Positioned(
                        left: _positions[table.name]!.dx,
                        top: _positions[table.name]!.dy,
                        child: _TableCard(
                          table: table,
                          focused: _focused == table.name,
                          dimmed:
                              related != null && !related.contains(table.name),
                          fkColumns: {
                            for (final edge in _edges)
                              if (edge.from == table.name) edge.fromColumn,
                          },
                          onTap: () => setState(() {
                            _focused = _focused == table.name
                                ? null
                                : table.name;
                          }),
                          onDoubleTap: () => widget.onOpenTable(table.name),
                          onDrag: (delta) => setState(() {
                            final scale = _viewController.value
                                .getMaxScaleOnAxis();
                            _positions[table.name] =
                                _positions[table.name]! + delta / scale;
                          }),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(left: 12, top: 12, child: _Legend()),
        Positioned(
          right: 12,
          top: 12,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _positions = _gridPositions(tables, _edges);
              _viewController.value = Matrix4.identity();
            }),
            icon: const Icon(Icons.grid_view_rounded, size: 14),
            label: const Text('Auto-arrange'),
            style: TextButton.styleFrom(
              foregroundColor: Palette.textMid,
              backgroundColor: Palette.paper.withValues(alpha: .92),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Palette.line),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.focused,
    required this.dimmed,
    required this.fkColumns,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDrag,
  });

  final TableSchema table;
  final bool focused;
  final bool dimmed;
  final Set<String> fkColumns;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final shownColumns = table.columns.take(_maxColumnRows).toList();
    final hidden = table.columns.length - shownColumns.length;
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onPanUpdate: (details) => onDrag(details.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: dimmed ? 0.3 : 1,
          child: Container(
            width: _cardWidth,
            decoration: BoxDecoration(
              color: Palette.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused ? Palette.blueprint : Palette.line,
                width: focused ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (focused)
                  BoxShadow(
                    color: Palette.blueprint.withValues(alpha: .22),
                    blurRadius: 20,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.table_chart_rounded,
                          size: 14,
                          color: Palette.blueprint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            table.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Palette.textHi,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (table.rowCount >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Palette.paperRaised,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Palette.line),
                            ),
                            child: Text(
                              '${table.rowCount}',
                              style: const TextStyle(
                                color: Palette.textMid,
                                fontFamily: monoFamily,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(height: 1, color: Palette.line),
                for (final column in shownColumns) _columnRow(column),
                if (hidden > 0)
                  SizedBox(
                    height: _footerHeight,
                    child: Center(
                      child: Text(
                        '+$hidden more columns',
                        style: const TextStyle(
                          color: Palette.textLow,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: _bottomPad),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _columnRow(ColumnSchema column) {
    final isFk = fkColumns.contains(column.name);
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: Center(
                child: column.isPrimaryKey
                    ? const Icon(
                        Icons.vpn_key_rounded,
                        size: 11,
                        color: Palette.brass,
                      )
                    : isFk
                    ? const Icon(
                        Icons.link_rounded,
                        size: 12,
                        color: Palette.blueprint,
                      )
                    : const Icon(
                        Icons.circle,
                        size: 3.5,
                        color: Palette.textLow,
                      ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                column.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: column.isPrimaryKey ? Palette.textHi : Palette.textMid,
                  fontFamily: monoFamily,
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              column.type.toUpperCase(),
              style: const TextStyle(color: Palette.textLow, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _labelStyle = TextStyle(color: Palette.textMid, fontSize: 10.5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.paper.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 2, color: Palette.blueprint),
              const SizedBox(width: 6),
              const Text('foreign key', style: _labelStyle),
              const SizedBox(width: 14),
              for (var i = 0; i < 3; i++)
                Container(
                  width: 4,
                  height: 2,
                  margin: const EdgeInsets.only(right: 2),
                  color: Palette.textMid,
                ),
              const SizedBox(width: 4),
              const Text('inferred', style: _labelStyle),
              const SizedBox(width: 14),
              const Icon(Icons.vpn_key_rounded, size: 10, color: Palette.brass),
              const SizedBox(width: 5),
              const Text('primary key', style: _labelStyle),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Drag cards · scroll to zoom · click to focus · double-click to query',
            style: TextStyle(color: Palette.textLow, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BlueprintPainter extends CustomPainter {
  _BlueprintPainter({
    required this.schema,
    required this.positions,
    required this.edges,
    required this.focused,
  });

  final DbSchema schema;
  final Map<String, Offset> positions;
  final List<_SchemaEdge> edges;
  final String? focused;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDotGrid(canvas, size);
    for (final edge in edges) {
      _paintEdge(canvas, edge);
    }
  }

  void _paintDotGrid(Canvas canvas, Size size) {
    const step = 28.0;
    final paint = Paint()
      ..color = Palette.grid
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(ui.PointMode.points, points, paint);
  }

  double _anchorY(TableSchema table, Offset position, String? columnName) {
    var index = columnName == null
        ? -1
        : table.columns.indexWhere((c) => c.name == columnName);
    if (index < 0) {
      index = table.columns.indexWhere((c) => c.isPrimaryKey);
    }
    if (index < 0) return position.dy + _headerHeight / 2;
    final shown = math.min(index, _maxColumnRows - 1);
    return position.dy +
        _headerHeight +
        1 +
        shown * _rowHeight +
        _rowHeight / 2;
  }

  void _paintEdge(Canvas canvas, _SchemaEdge edge) {
    final fromTable = schema.table(edge.from);
    final toTable = schema.table(edge.to);
    final fromPos = positions[edge.from];
    final toPos = positions[edge.to];
    if (fromTable == null ||
        toTable == null ||
        fromPos == null ||
        toPos == null) {
      return;
    }

    final ys = _anchorY(fromTable, fromPos, edge.fromColumn);
    final yt = _anchorY(toTable, toPos, edge.toColumn);

    Offset start, end, c1, c2;
    const gap = 24.0;
    const reach = 56.0;
    if (toPos.dx >= fromPos.dx + _cardWidth + gap) {
      start = Offset(fromPos.dx + _cardWidth, ys);
      end = Offset(toPos.dx, yt);
      c1 = start.translate(reach, 0);
      c2 = end.translate(-reach, 0);
    } else if (fromPos.dx >= toPos.dx + _cardWidth + gap) {
      start = Offset(fromPos.dx, ys);
      end = Offset(toPos.dx + _cardWidth, yt);
      c1 = start.translate(-reach, 0);
      c2 = end.translate(reach, 0);
    } else {
      // Cards overlap horizontally: hook around their right side.
      final rightMost = math.max(fromPos.dx, toPos.dx) + _cardWidth;
      start = Offset(fromPos.dx + _cardWidth, ys);
      end = Offset(toPos.dx + _cardWidth, yt);
      c1 = Offset(rightMost + 70, ys);
      c2 = Offset(rightMost + 70, yt);
    }

    final related =
        focused == null || edge.from == focused || edge.to == focused;
    final highlighted = focused != null && related;
    var color = edge.inferred ? Palette.textMid : Palette.blueprint;
    if (!related) color = color.withValues(alpha: .1);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 2.2 : 1.4
      ..color = color;

    var path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    if (edge.inferred) path = _dashed(path);
    canvas.drawPath(path, paint);

    // Socket at the source column, arrowhead into the referenced table.
    canvas.drawCircle(start, 2.6, Paint()..color = color);
    final angle = (end - c2).direction;
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(angle);
    final arrow = Path()
      ..moveTo(0, 0)
      ..lineTo(-7, 4)
      ..lineTo(-7, -4)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
    canvas.restore();
  }

  Path _dashed(Path source, {double dash = 6, double gap = 4}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dest.addPath(
          metric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _BlueprintPainter oldDelegate) => true;
}
