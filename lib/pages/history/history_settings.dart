import 'package:flutter/material.dart';
import 'history_page.dart';

enum ViewPreset {
  images,
  galleriesFolder,
  celebrityAlbum,
}

enum ViewType {
  list,
  grid,
}

class ViewPresetSelector extends StatelessWidget {
  final ViewPreset currentPreset;
  final ViewType currentViewType;
  final Function(ViewPreset) onPresetSelected;
  final Function(ViewType) onViewTypeSelected;

  const ViewPresetSelector({
    super.key,
    required this.currentPreset,
    required this.currentViewType,
    required this.onPresetSelected,
    required this.onViewTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'View Preset',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.image,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Images'),
            trailing: currentPreset == ViewPreset.images
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onPresetSelected(ViewPreset.images),
          ),
          ListTile(
            leading: Icon(
              Icons.folder,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Galleries Folder'),
            trailing: currentPreset == ViewPreset.galleriesFolder
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onPresetSelected(ViewPreset.galleriesFolder),
          ),
          ListTile(
            leading: Icon(
              Icons.person,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Celebrity Album'),
            trailing: currentPreset == ViewPreset.celebrityAlbum
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onPresetSelected(ViewPreset.celebrityAlbum),
          ),
          const Divider(),
          const Text(
            'View Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.list,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('List View'),
            trailing: currentViewType == ViewType.list
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onViewTypeSelected(ViewType.list),
          ),
          ListTile(
            leading: Icon(
              Icons.grid_view,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Grid View'),
            trailing: currentViewType == ViewType.grid
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onViewTypeSelected(ViewType.grid),
          ),
        ],
      ),
    );
  }
}

class SortOptionsSheet extends StatelessWidget {
  final SortOption currentSort;
  final Function(SortOption) onSortSelected;

  const SortOptionsSheet({
    super.key,
    required this.currentSort,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort By',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.access_time,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Newest First'),
            trailing: currentSort == SortOption.newest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.newest),
          ),
          ListTile(
            leading: Icon(
              Icons.access_time,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Oldest First'),
            trailing: currentSort == SortOption.oldest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.oldest),
          ),
          ListTile(
            leading: Icon(
              Icons.storage,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Largest First'),
            trailing: currentSort == SortOption.largest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.largest),
          ),
          ListTile(
            leading: Icon(
              Icons.storage,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Smallest First'),
            trailing: currentSort == SortOption.smallest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.smallest),
          ),
        ],
      ),
    );
  }
}