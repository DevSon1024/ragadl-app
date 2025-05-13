import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  _StoragePageState createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  String _baseDownloadPath = '/storage/emulated/0/Download';
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
      setState(() {
        _pathController.text = _baseDownloadPath;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Download path set to: $path')));
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
    await _savePath('/storage/emulated/0/Download');
    setState(() {
      _pathController.text = _baseDownloadPath;
    });
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Download Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a base directory for downloads. The structure will be: '
              '[Your Path]/Ragalahari Downloads/[folder]/[subfolder]',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Base Download Path',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFolder,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Pick Folder'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDefaultPath ? null : _resetToDefault,
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Default'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Current Path: $_baseDownloadPath/Ragalahari Downloads/[folder]/[subfolder]',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
