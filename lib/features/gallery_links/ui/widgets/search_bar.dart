import 'package:flutter/material.dart';

class GallerySearchBar extends StatelessWidget {
  final TextEditingController searchController;

  const GallerySearchBar({
    super.key,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search by gallery code...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              searchController.clear();
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainer,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }
}