import 'package:flutter/material.dart';

import 'inspector_service.dart';
import 'models.dart';
import 'theme.dart';
import 'views/data_view.dart';
import 'views/schema_map_view.dart';

enum InspectorView { data, map }

enum LogLevel { info, success, error }

class LogEntry {
  LogEntry(this.message, this.level) : time = DateTime.now();

  final String message;
  final LogLevel level;
  final DateTime time;
}

class InspectorShell extends StatefulWidget {
  const InspectorShell({super.key});

  @override
  State<InspectorShell> createState() => _InspectorShellState();
}

class _InspectorShellState extends State<InspectorShell> {
  final _service = InspectorService();
  final _sqlController = TextEditingController();
  final _searchController = TextEditingController();

  DbSchema _schema = const DbSchema(tables: []);
  InspectorView _view = InspectorView.data;
  String? _selectedTable;
  QueryResult? _result;
  String? _queryError;
  bool _loading = false;
  bool _consoleOpen = false;
  final List<LogEntry> _logs = [];

  static const _writePrefixes = [
    'INSERT',
    'UPDATE',
    'DELETE',
    'REPLACE',
    'CREATE',
    'DROP',
    'ALTER',
  ];

  @override
  void initState() {
    super.initState();
    _log('Waiting for the connected app…', LogLevel.info);
    _refreshSchema();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _log(String message, LogLevel level) {
    setState(() => _logs.add(LogEntry(message, level)));
  }

  Future<void> _refreshSchema() async {
    setState(() => _loading = true);
    try {
      final schema = await _service.fetchSchema();
      setState(() => _schema = schema);
      _log(
        'Loaded ${schema.tables.length} tables from the connected app.',
        LogLevel.success,
      );
    } catch (e) {
      _log('Could not load the schema: $e', LogLevel.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTable(String name) {
    final quoted = '"${name.replaceAll('"', '""')}"';
    final sql = 'SELECT * FROM $quoted;';
    setState(() {
      _view = InspectorView.data;
      _selectedTable = name;
      _sqlController.text = sql;
    });
    _runQuery(sql);
  }

  Future<void> _runQuery(String sql) async {
    final query = sql.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _queryError = null;
    });
    _log('> $query', LogLevel.info);
    try {
      final result = await _service.executeQuery(query);
      setState(() => _result = result);
      _log(
        '${result.rows.length} rows in ${result.elapsed.inMilliseconds} ms.',
        LogLevel.success,
      );
      final upper = query.toUpperCase();
      if (_writePrefixes.any(upper.startsWith)) {
        // Keep row counts and the schema map current after writes.
        await _refreshSchema();
      }
    } catch (e) {
      setState(() {
        _result = null;
        _queryError = '$e';
      });
      _log('$e', LogLevel.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.trim().toLowerCase();
    final filtered = [
      for (final table in _schema.tables)
        if (search.isEmpty || table.name.toLowerCase().contains(search)) table,
    ];
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(filtered),
          Container(width: 1, color: Palette.line),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                SizedBox(
                  height: 2,
                  child: _loading
                      ? const LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: Palette.blueprint,
                        )
                      : null,
                ),
                Expanded(child: _buildContent()),
                _buildConsole(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_schema.tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_rounded, size: 36, color: Palette.textLow),
            const SizedBox(height: 14),
            const Text(
              'No tables found',
              style: TextStyle(
                color: Palette.textHi,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: const Text(
                'Run your app in debug mode and call '
                'SqliteInspector.register(db) after opening the database, '
                'then refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Palette.textMid,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refreshSchema,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.blueprint,
                foregroundColor: Palette.canvas,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    return switch (_view) {
      InspectorView.data => DataView(
          sqlController: _sqlController,
          onRun: _runQuery,
          result: _result,
          error: _queryError,
        ),
      InspectorView.map => SchemaMapView(
          schema: _schema,
          onOpenTable: _openTable,
        ),
    };
  }

  Widget _buildSidebar(List<TableSchema> filtered) {
    return SizedBox(
      width: 232,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Palette.paperRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.line),
                  ),
                  child: const Icon(
                    Icons.storage_rounded,
                    size: 16,
                    color: Palette.blueprint,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SQLite Inspector',
                        style: TextStyle(
                          color: Palette.textHi,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'live database blueprint',
                        style:
                            TextStyle(color: Palette.textLow, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Palette.textHi, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Filter tables',
                hintStyle:
                    const TextStyle(color: Palette.textLow, fontSize: 12.5),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: Palette.textLow,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                isDense: true,
                filled: true,
                fillColor: Palette.paper,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                const PanelLabel('Tables'),
                const Spacer(),
                Text(
                  '${_schema.tables.length}',
                  style: const TextStyle(
                    color: Palette.textLow,
                    fontFamily: monoFamily,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No tables match',
                      style: TextStyle(color: Palette.textLow, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final table = filtered[index];
                      final selected = table.name == _selectedTable;
                      return InkWell(
                        onTap: () => _openTable(table.name),
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: selected ? Palette.paperRaised : null,
                          child: Row(
                            children: [
                              Icon(
                                Icons.table_chart_outlined,
                                size: 13,
                                color: selected
                                    ? Palette.blueprint
                                    : Palette.textLow,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  table.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Palette.blueprint
                                        : Palette.textHi,
                                    fontFamily: monoFamily,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (table.rowCount >= 0)
                                Text(
                                  '${table.rowCount}',
                                  style: const TextStyle(
                                    color: Palette.textLow,
                                    fontFamily: monoFamily,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Row(
        children: [
          _ViewToggle(
            view: _view,
            onChanged: (view) => setState(() => _view = view),
          ),
          const Spacer(),
          IconButton(
            onPressed: _refreshSchema,
            tooltip: 'Refresh schema',
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Palette.textMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsole() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _consoleOpen = !_consoleOpen),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Palette.paper,
              border: Border(top: BorderSide(color: Palette.line)),
            ),
            child: Row(
              children: [
                const PanelLabel('Console'),
                const SizedBox(width: 8),
                Text(
                  '${_logs.length}',
                  style: const TextStyle(
                    color: Palette.textLow,
                    fontFamily: monoFamily,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                if (_consoleOpen)
                  InkWell(
                    onTap: () => setState(() => _logs.clear()),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Clear',
                        style:
                            TextStyle(color: Palette.textLow, fontSize: 11),
                      ),
                    ),
                  ),
                Icon(
                  _consoleOpen
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 16,
                  color: Palette.textLow,
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: _consoleOpen ? 150 : 0,
          color: Palette.canvas,
          child: !_consoleOpen
              ? null
              : SelectionArea(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final entry = _logs[_logs.length - 1 - index];
                      final color = switch (entry.level) {
                        LogLevel.info => Palette.textMid,
                        LogLevel.success => Palette.mint,
                        LogLevel.error => Palette.rose,
                      };
                      final time = entry.time;
                      String two(int n) => n.toString().padLeft(2, '0');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${two(time.hour)}:${two(time.minute)}:'
                              '${two(time.second)}',
                              style: const TextStyle(
                                color: Palette.textLow,
                                fontFamily: monoFamily,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.message,
                                style: TextStyle(
                                  color: color,
                                  fontFamily: monoFamily,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final InspectorView view;
  final ValueChanged<InspectorView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(InspectorView.data, Icons.table_rows_rounded, 'Data'),
          const SizedBox(width: 2),
          _chip(InspectorView.map, Icons.account_tree_rounded, 'Schema map'),
        ],
      ),
    );
  }

  Widget _chip(InspectorView value, IconData icon, String label) {
    final selected = view == value;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Palette.paperRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Palette.line : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Palette.blueprint : Palette.textLow,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Palette.textHi : Palette.textMid,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
