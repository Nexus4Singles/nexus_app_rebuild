import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Searchable picker for long lists (hobbies, professions, states, etc.)
/// Features:
/// - Text search input at top
/// - Type-to-filter results
/// - Alphabetical grouping (optional)
/// - Multi-select support
/// - Premium red/white styling
class SearchablePicker extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> selectedItems;
  final bool multiSelect;
  final int? maxSelections;
  final bool alphabeticalGrouping;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback? onClose;

  const SearchablePicker({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItems,
    this.multiSelect = false,
    this.maxSelections,
    this.alphabeticalGrouping = true,
    required this.onChanged,
    this.onClose,
  });

  @override
  State<SearchablePicker> createState() => _SearchablePickerState();
}

class _SearchablePickerState extends State<SearchablePicker> {
  late TextEditingController _searchController;
  late List<String> _filteredItems;
  late Set<String> _selectedSet;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = List.from(widget.items);
    _selectedSet = Set.from(widget.selectedItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _toggleItem(String item) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSet.contains(item)) {
        _selectedSet.remove(item);
      } else {
        if (widget.multiSelect) {
          if (widget.maxSelections == null || 
              _selectedSet.length < widget.maxSelections!) {
            _selectedSet.add(item);
          } else {
            // Show max reached feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Maximum ${widget.maxSelections} selections allowed'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.warning,
              ),
            );
          }
        } else {
          _selectedSet.clear();
          _selectedSet.add(item);
        }
      }
    });
    widget.onChanged(_selectedSet.toList());
  }

  Map<String, List<String>> _groupByAlphabet() {
    final Map<String, List<String>> grouped = {};
    for (final item in _filteredItems) {
      final letter = item.isNotEmpty ? item[0].toUpperCase() : '#';
      grouped.putIfAbsent(letter, () => []).add(item);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.multiSelect && widget.maxSelections != null)
                        Text(
                          '${_selectedSet.length}/${widget.maxSelections} selected',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _filterItems,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _filterItems('');
                          },
                          icon: Icon(Icons.clear, color: AppColors.textMuted),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Selected chips (if multi-select and has selections)
          if (widget.multiSelect && _selectedSet.isNotEmpty)
            Container(
              height: 44,
              padding: const EdgeInsets.only(left: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedSet.length,
                itemBuilder: (context, index) {
                  final item = _selectedSet.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: AppColors.primary,
                      deleteIconColor: Colors.white,
                      onDeleted: () => _toggleItem(item),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),

          // List
          Expanded(
            child: _filteredItems.isEmpty
                ? _buildEmptyState()
                : widget.alphabeticalGrouping
                    ? _buildGroupedList()
                    : _buildSimpleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final grouped = _groupByAlphabet();
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final letter = grouped.keys.elementAt(index);
        final items = grouped[letter]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Letter header
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            // Items
            ...items.map((item) => _buildItemTile(item)),
          ],
        );
      },
    );
  }

  Widget _buildSimpleList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) => _buildItemTile(_filteredItems[index]),
    );
  }

  Widget _buildItemTile(String item) {
    final isSelected = _selectedSet.contains(item);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleItem(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SHOW PICKER HELPER FUNCTIONS
// ============================================================================

/// Show a searchable single-select picker
Future<String?> showSearchablePicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? selectedItem,
  bool alphabeticalGrouping = true,
}) async {
  String? result = selectedItem;
  
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SearchablePicker(
      title: title,
      items: items,
      selectedItems: selectedItem != null ? [selectedItem] : [],
      multiSelect: false,
      alphabeticalGrouping: alphabeticalGrouping,
      onChanged: (selected) {
        result = selected.isNotEmpty ? selected.first : null;
      },
    ),
  );
  
  return result;
}

/// Show a searchable multi-select picker
Future<List<String>?> showMultiSelectPicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  List<String>? selectedItems,
  int? maxSelections,
  bool alphabeticalGrouping = true,
}) async {
  List<String> result = List.from(selectedItems ?? []);
  
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SearchablePicker(
      title: title,
      items: items,
      selectedItems: result,
      multiSelect: true,
      maxSelections: maxSelections,
      alphabeticalGrouping: alphabeticalGrouping,
      onChanged: (selected) {
        result = selected;
      },
    ),
  );
  
  return result;
}

// ============================================================================
// PICKER FIELD WIDGET (for forms)
// ============================================================================

/// A form field that shows a searchable picker when tapped
class PickerFormField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isRequired;
  final bool showChevron;

  const PickerFormField({
    super.key,
    required this.label,
    this.value,
    required this.hint,
    this.icon,
    required this.onTap,
    this.isRequired = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Field
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue ? AppColors.primary.withOpacity(0.3) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: hasValue ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    hasValue ? value! : hint,
                    style: TextStyle(
                      fontSize: 15,
                      color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showChevron)
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A form field for multi-select that shows selected items as chips
class MultiPickerFormField extends StatelessWidget {
  final String label;
  final List<String> values;
  final String hint;
  final IconData? icon;
  final VoidCallback onTap;
  final ValueChanged<String>? onRemove;
  final bool isRequired;
  final int? maxDisplay;

  const MultiPickerFormField({
    super.key,
    required this.label,
    required this.values,
    required this.hint,
    this.icon,
    required this.onTap,
    this.onRemove,
    this.isRequired = false,
    this.maxDisplay = 3,
  });

  @override
  Widget build(BuildContext context) {
    final hasValues = values.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            if (hasValues) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${values.length} selected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        
        // Field
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValues ? AppColors.primary.withOpacity(0.3) : AppColors.border,
              ),
            ),
            child: hasValues
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...values.take(maxDisplay ?? values.length).map((value) => Chip(
                        label: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                        deleteIconColor: Colors.white,
                        onDeleted: onRemove != null ? () => onRemove!(value) : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )),
                      if (values.length > (maxDisplay ?? values.length))
                        Chip(
                          label: Text(
                            '+${values.length - (maxDisplay ?? values.length)} more',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          backgroundColor: AppColors.surfaceLight,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  )
                : Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: AppColors.textMuted),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          hint,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Icon(Icons.add, color: AppColors.primary),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
