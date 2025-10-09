import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'dart:convert';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  _StoragePageState createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  String _baseDownloadPath = '';
  final TextEditingController _pathController = TextEditingController();
  bool _isDefaultPath = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
  }

  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('base_download_path');

    if (savedPath != null && savedPath.isNotEmpty) {
      setState(() {
        _baseDownloadPath = savedPath;
        _pathController.text = savedPath;
        _isDefaultPath = false;
      });
    } else {
      String defaultPath;
      if (Platform.isWindows) {
        final docsDir = await getApplicationDocumentsDirectory();
        defaultPath = '${docsDir.path}/Downloads';
      } else {
        defaultPath = '/storage/emulated/0/Download';
      }

      setState(() {
        _baseDownloadPath = defaultPath;
        _pathController.text = defaultPath;
        _isDefaultPath = true;
      });
    }
  }

  Future<void> _savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_download_path', path);
    setState(() {
      _baseDownloadPath = path;
      _isDefaultPath = path == '/storage/emulated/0/Download';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download path set to: $path'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _pathController.text = selectedDirectory;
      });
      await _savePath(selectedDirectory);
    }
  }

  Future<void> _resetToDefault() async {
    String defaultPath;
    if (Platform.isWindows) {
      final docsDir = await getApplicationDocumentsDirectory();
      defaultPath = '${docsDir.path}/Downloads';
    } else {
      defaultPath = '/storage/emulated/0/Download';
    }

    await _savePath(defaultPath);
    setState(() {
      _pathController.text = defaultPath;
    });
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _loadSavedPath();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cache cleared successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      if (Platform.isAndroid) {
        final storagePermission = await Permission.storage.request();
        final manageStoragePermission = await Permission.manageExternalStorage.request();

        if (storagePermission != PermissionStatus.granted &&
            manageStoragePermission != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Storage permission denied'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final archive = Archive();

      // Export favorites
      final favorites = prefs.getStringList('favorites') ?? [];
      archive.addFile(ArchiveFile(
        'favorites.json',
        utf8.encode(jsonEncode(favorites)).length,
        utf8.encode(jsonEncode(favorites)),
      ));

      // Export link history
      final history = prefs.getStringList('link_history') ?? [];
      archive.addFile(ArchiveFile(
        'link_history.json',
        utf8.encode(jsonEncode(history)).length,
        utf8.encode(jsonEncode(history)),
      ));

      // Export display settings
      final displaySettings = {
        'theme_mode': prefs.getInt('theme_mode') ?? 0,
        'theme_name': prefs.getString('theme_name') ?? 'google',
        'grid_columns': prefs.getInt('grid_columns') ?? 2,
      };
      archive.addFile(ArchiveFile(
        'display_settings.json',
        utf8.encode(jsonEncode(displaySettings)).length,
        utf8.encode(jsonEncode(displaySettings)),
      ));

      // Export storage settings
      final storageSettings = {
        'base_download_path': prefs.getString('base_download_path') ?? '',
      };
      archive.addFile(ArchiveFile(
        'storage_settings.json',
        utf8.encode(jsonEncode(storageSettings)).length,
        utf8.encode(jsonEncode(storageSettings)),
      ));

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No folder selected for backup'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      String finalDirectory = selectedDirectory;
      try {
        final directory = Directory(selectedDirectory);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } catch (e) {
        final appDir = await getExternalStorageDirectory();
        if (appDir == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Unable to access storage'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        finalDirectory = appDir.path;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected folder inaccessible, using: $finalDirectory'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final zipPath = '$finalDirectory/ragalahari_backup_$timestamp.zip';

      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);

      if (zipData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to create ZIP file'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to: $zipPath'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during backup: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );

    if (result == null || result.files.isEmpty) return;

    final zipFile = File(result.files.single.path!);
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final prefs = await SharedPreferences.getInstance();

    for (final file in archive) {
      final data = file.content as List<int>;
      final jsonString = utf8.decode(data);

      if (file.name == 'favorites.json') {
        final favorites = jsonDecode(jsonString) as List;
        await prefs.setStringList('favorites', favorites.cast<String>());
      } else if (file.name == 'link_history.json') {
        final history = jsonDecode(jsonString) as List;
        await prefs.setStringList('link_history', history.cast<String>());
      } else if (file.name == 'display_settings.json') {
        final settings = jsonDecode(jsonString) as Map<String, dynamic>;
        await prefs.setInt('theme_mode', settings['theme_mode'] as int);
        await prefs.setString('theme_name', settings['theme_name'] as String);
        await prefs.setInt('grid_columns', settings['grid_columns'] as int);
      } else if (file.name == 'storage_settings.json') {
        final settings = jsonDecode(jsonString) as Map<String, dynamic>;
        await prefs.setString('base_download_path', settings['base_download_path'] as String);
      }
    }

    await _loadSavedPath();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data restored successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: color.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Storage Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.primaryContainer.withOpacity(0.25),
              color.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeroHeader(context),
              const SizedBox(height: 16),
              _buildDownloadPathSection(context),
              const SizedBox(height: 16),
              _buildDataManagementSection(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.primary.withOpacity(0.90),
            color.primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.primary.withOpacity(0.25),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.onPrimary.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            left: -16,
            bottom: -16,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.onPrimary.withOpacity(0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.onPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.storage_rounded,
                        color: color.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Storage Management',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color.onPrimary,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Configure download paths, manage app data, and backup your settings.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color.onPrimary.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPathSection(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return _Glass(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_rounded, color: color.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Download Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: color.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.outline.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded,
                      color: color.primary,
                      size: 20
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Path',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: color.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _baseDownloadPath,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.folder_open,
                    label: 'Choose Folder',
                    onTap: _pickFolder,
                    color: color.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.restore,
                    label: 'Reset Default',
                    onTap: _isDefaultPath ? null : _resetToDefault,
                    color: color.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return _Glass(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_backup_restore_rounded,
                    color: color.primary,
                    size: 20
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsTile(
              icon: Icons.backup_rounded,
              title: 'Backup Data',
              subtitle: 'Export favorites, history, and settings',
              color: color.tertiary,
              onTap: _exportData,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.restore_rounded,
              title: 'Restore Data',
              subtitle: 'Import previously backed up data',
              color: color.tertiary,
              onTap: _importData,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: 'Clear Cache',
              subtitle: 'Remove all app data and reset settings',
              color: color.error,
              onTap: _clearCache,
            ),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: color.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: color.shadow.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: onTap == null
          ? scheme.surfaceVariant.withOpacity(0.3)
          : color.withOpacity(0.12),
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  icon,
                  color: onTap == null
                      ? scheme.onSurfaceVariant.withOpacity(0.5)
                      : color,
                  size: 20
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: onTap == null
                        ? scheme.onSurfaceVariant.withOpacity(0.5)
                        : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.12),
                      color.withOpacity(0.22),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
