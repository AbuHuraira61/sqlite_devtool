import 'package:flutter/material.dart';

import '../inspector_service.dart';
import '../theme.dart';

const _maxRowsShown = 500;

/// SQL console plus results grid.
class DataView extends StatelessWidget {
  const DataView({
    super.key,
    required this.sqlController,
    required this.onRun,
    required this.result,
    required this.error,
  });

  final TextEditingController sqlController;
  final void Function(String sql) onRun;
  final QueryResult? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sqlController,
                  onSubmitted: onRun,
                  style: TextStyle(
                    color: Palette.textHi,
                    fontFamily: monoFamily,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a SQL statement and press Enter…',
                    hintStyle: const TextStyle(
                      color: Palette.textLow,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Palette.paper,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Palette.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Palette.blueprint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => onRun(sqlController.text),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.blueprint,
                  foregroundColor: Palette.canvas,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run query'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildResults()),
        if (result != null) _StatusBar(result: result!),
      ],
    );
  }

  Widget _buildResults() {
    final error = this.error;
    if (error != null) {
      return _CenteredNote(
        icon: Icons.error_outline_rounded,
        iconColor: Palette.rose,
        title: 'Query failed',
        child: SelectableText(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Palette.textMid,
            fontFamily: monoFamily,
            fontSize: 12,
          ),
        ),
      );
    }
    final result = this.result;
    if (result == null) {
      return const _CenteredNote(
        icon: Icons.table_view_rounded,
        iconColor: Palette.textLow,
        title: 'No results yet',
        child: Text(
          'Select a table from the sidebar or run a query.',
          style: TextStyle(color: Palette.textLow, fontSize: 12.5),
        ),
      );
    }
    if (result.rows.isEmpty) {
      return const _CenteredNote(
        icon: Icons.check_circle_outline_rounded,
        iconColor: Palette.mint,
        title: 'Statement ran',
        child: Text(
          'No rows returned.',
          style: TextStyle(color: Palette.textLow, fontSize: 12.5),
        ),
      );
    }
    return _ResultsGrid(rows: result.rows.take(_maxRowsShown).toList());
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final columns = rows.first.keys.toList();
    return SelectionArea(
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 30,
              horizontalMargin: 12,
              columnSpacing: 28,
              headingRowColor: const WidgetStatePropertyAll(Palette.paper),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Palette.line.withValues(alpha: .6),
                  width: .5,
                ),
              ),
              columns: [
                for (final column in columns)
                  DataColumn(
                    label: Text(
                      column,
                      style: const TextStyle(
                        color: Palette.blueprint,
                        fontFamily: monoFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(
                    color: i.isOdd
                        ? const WidgetStatePropertyAll(Color(0x0DFFFFFF))
                        : null,
                    cells: [
                      for (final column in columns) _cell(rows[i][column]),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataCell _cell(Object? value) {
    if (value == null) {
      return const DataCell(
        Text(
          'NULL',
          style: TextStyle(
            color: Palette.textLow,
            fontFamily: monoFamily,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final text = value.toString();
    final cell = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Palette.textHi,
          fontFamily: monoFamily,
          fontSize: 12,
        ),
      ),
    );
    return DataCell(
      text.length > 48 ? Tooltip(message: text, child: cell) : cell,
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.result});

  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final total = result.rows.length;
    final capped = total > _maxRowsShown;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      child: Row(
        children: [
          Text(
            '$total ${total == 1 ? 'row' : 'rows'} · '
            '${result.elapsed.inMilliseconds} ms',
            style: const TextStyle(
              color: Palette.textMid,
              fontFamily: monoFamily,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (capped)
            Text(
              'showing first $_maxRowsShown rows',
              style: const TextStyle(
                color: Palette.brass,
                fontFamily: monoFamily,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Palette.textHi,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}
