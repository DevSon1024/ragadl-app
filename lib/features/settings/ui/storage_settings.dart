import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart'; // Add for ZIP handling
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download path set to: $path'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cache cleared successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      // Request storage permissions
      if (Platform.isAndroid) {
        final storagePermission = await Permission.storage.request();
        final manageStoragePermission = await Permission.manageExternalStorage.request();
        if (storagePermission != PermissionStatus.granted &&
            manageStoragePermission != PermissionStatus.granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Storage permission denied'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
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

      // Choose folder to save ZIP
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No folder selected for backup'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Fallback to app-specific storage if selected directory is inaccessible
      String finalDirectory = selectedDirectory;
      try {
        final directory = Directory(selectedDirectory);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } catch (e) {
        // Fallback to app-specific external storage
        final appDir = await getExternalStorageDirectory();
        if (appDir == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to access storage'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
        finalDirectory = appDir.path;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected folder inaccessible, using: $finalDirectory'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      // Create ZIP file path with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final zipPath = '$finalDirectory/ragalahari_backup_$timestamp.zip';

      // Encode and save ZIP file
      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);

      if (zipData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create ZIP file'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved to: $zipPath'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during backup: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
        final favorites = jsonDecode(jsonString) as List<dynamic>;
        await prefs.setStringList('favorites', favorites.cast<String>());
      } else if (file.name == 'link_history.json') {
        final history = jsonDecode(jsonString) as List<dynamic>;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data restored successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Storage Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Settings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure download location and manage app data.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Single Container with all settings
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              surfaceTintColor: theme.colorScheme.surfaceTint,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Download Path Section
                    Text(
                      'Download Path',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pathController,
                      decoration: InputDecoration(
                        labelText: 'Base Download Path',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainer,
                        prefixIcon: const Icon(Icons.folder),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      readOnly: true,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),

                    // All Action Buttons in Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFolder,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Pick Folder', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isDefaultPath ? null : _resetToDefault,
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Reset Default', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                            foregroundColor: theme.colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _exportData,
                          icon: const Icon(Icons.backup, size: 18),
                          label: const Text('Backup', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiary,
                            foregroundColor: theme.colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _importData,
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Restore', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiary,
                            foregroundColor: theme.colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Clear Cache Button (full width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _clearCache,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Clear Cache'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Current Path Info (simplified)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Path: $_baseDownloadPath',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // Bottom padding for scroll
          ],
        ),
      ),
    );
  }
}