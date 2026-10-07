import 'package:flutter/material.dart';

import 'dos_search_bar.dart';
import 'dos_table.dart';
import '../utils/nav_utils.dart';

/// Barre RECH> + tableau avec navigation clavier ↓ (recherche → tableau)
/// et ↑ sur la 1re ligne (tableau → recherche).
class DosSearchableTable extends StatefulWidget {
  const DosSearchableTable({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.headers,
    required this.rows,
    this.searchHint = 'Rechercher…',
    this.onSelect,
    this.onCancel,
    this.onSelectionChanged,
    this.emptyMessage = 'Aucune donnée.',
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;
  final List<String> headers;
  final List<List<String>> rows;
  final void Function(int index)? onSelect;
  final VoidCallback? onCancel;
  final void Function(int index)? onSelectionChanged;
  final String emptyMessage;

  @override
  State<DosSearchableTable> createState() => DosSearchableTableState();
}

class DosSearchableTableState extends State<DosSearchableTable> {
  final _searchFocus = FocusNode();
  final _tableKey = GlobalKey<DosTableState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void focusSearch() => _searchFocus.requestFocus();

  void focusTable() => _tableKey.currentState?.focusTable();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DosSearchBar(
          controller: widget.searchController,
          onChanged: widget.onSearchChanged,
          hint: widget.searchHint,
          focusNode: _searchFocus,
          onMoveDown: focusTable,
          onEscape: () => guardedPopRoute(context),
        ),
        Expanded(
          child: DosTable(
            key: _tableKey,
            headers: widget.headers,
            rows: widget.rows,
            autofocus: false,
            onMoveUpFromTop: focusSearch,
            onSelect: widget.onSelect,
            onCancel: widget.onCancel,
            onSelectionChanged: widget.onSelectionChanged,
            emptyMessage: widget.emptyMessage,
          ),
        ),
      ],
    );
  }
}
