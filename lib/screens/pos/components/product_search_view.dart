import 'package:flutter/material.dart';
import 'package:prostock/utils/app_constants.dart';

class ProductSearchView extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const ProductSearchView({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<ProductSearchView> createState() => _ProductSearchViewState();
}

class _ProductSearchViewState extends State<ProductSearchView> {
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isSearching = widget.controller.text.isNotEmpty;
    });
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(UiConstants.spacingMedium),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search products by name, barcode, or description...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                  tooltip: 'Clear search',
                )
              : null,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          // Trigger search immediately on submit
          widget.onChanged(value);
        },
      ),
    );
  }
}
