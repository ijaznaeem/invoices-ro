import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SearchableOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final String? searchText;

  const SearchableOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.searchText,
  });

  String get haystack =>
      (searchText ?? '$label ${subtitle ?? ''}').toLowerCase();
}

/// Form-field style control that opens a searchable bottom sheet picker.
class SearchableDropdown<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final T? value;
  final List<SearchableOption<T>> items;
  final ValueChanged<T?> onChanged;
  final String searchHint;
  final IconData prefixIcon;
  final bool allowClear;
  final String? clearLabel;
  final String? Function(T?)? validator;
  final String emptyMessage;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.searchHint = 'Search…',
    this.prefixIcon = Icons.search_rounded,
    this.allowClear = false,
    this.clearLabel,
    this.validator,
    this.emptyMessage = 'No matches',
  });

  String get _displayText {
    if (value == null) return hint ?? 'Select…';
    final match = items.where((o) => o.value == value).firstOrNull;
    return match?.label ?? hint ?? 'Select…';
  }

  String? get _subtitle {
    if (value == null) return null;
    return items.where((o) => o.value == value).firstOrNull?.subtitle;
  }

  Future<void> _pick(BuildContext context) async {
    final result = await showModalBottomSheet<_PickResult<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SearchablePickerSheet<T>(
        title: label,
        items: items,
        selected: value,
        searchHint: searchHint,
        allowClear: allowClear,
        clearLabel: clearLabel ?? 'Clear selection',
        emptyMessage: emptyMessage,
      ),
    );
    if (!context.mounted || result == null) return;
    if (result.cleared) {
      onChanged(null);
    } else {
      onChanged(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return FormField<T>(
      key: ValueKey(value),
      initialValue: value,
      validator: validator,
      builder: (field) {
        return InkWell(
          onTap: () async {
            await _pick(context);
          },
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            isEmpty: !hasValue,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(prefixIcon),
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              errorText: field.errorText,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasValue ? null : Theme.of(context).hintColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PickResult<T> {
  final T? value;
  final bool cleared;
  _PickResult.selected(this.value) : cleared = false;
  _PickResult.clear()
      : value = null,
        cleared = true;
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  final String title;
  final List<SearchableOption<T>> items;
  final T? selected;
  final String searchHint;
  final bool allowClear;
  final String clearLabel;
  final String emptyMessage;

  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.searchHint,
    required this.allowClear,
    required this.clearLabel,
    required this.emptyMessage,
  });

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  final _query = TextEditingController();
  late List<SearchableOption<T>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _query.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _query.removeListener(_applyFilter);
    _query.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _query.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items.where((o) => o.haystack.contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _query.clear(),
                      ),
              ),
            ),
          ),
          if (widget.allowClear)
            ListTile(
              leading: const Icon(Icons.backspace_outlined),
              title: Text(widget.clearLabel),
              onTap: () => Navigator.pop(context, _PickResult<T>.clear()),
            ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      widget.emptyMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final option = _filtered[index];
                      final selected = option.value == widget.selected;
                      return ListTile(
                        selected: selected,
                        selectedTileColor:
                            LedgerColors.primary.withValues(alpha: 0.08),
                        title: Text(option.label),
                        subtitle: option.subtitle == null
                            ? null
                            : Text(option.subtitle!),
                        trailing: selected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () => Navigator.pop(
                          context,
                          _PickResult.selected(option.value),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
