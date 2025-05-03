import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
// import 'models/image_data.dart';
// import 'package:open_filex/open_filex.dart';

enum DownloadStatus { downloading, paused, completed, failed }

class DownloadTask {
  final String url;
  final double progress;
  final DownloadStatus status;

  DownloadTask({
    required this.url,
    required this.progress,
    required this.status,
  });

  DownloadTask copyWith({
    String? url,
    double? progress,
    DownloadStatus? status,
  }) {
    return DownloadTask(
      url: url ?? this.url,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

class DownloadManager {
  final Map<String, DownloadTask> _activeDownloads = {};
  final Dio _dio = Dio();

  Future<void> addDownload({
    required String url,
    required String folder,
    required String subFolder,
    required void Function(double progress) onProgress,
  }) async {
    if (_activeDownloads.containsKey(url)) return;

    final task = DownloadTask(
      url: url,
      progress: 0,
      status: DownloadStatus.downloading,
    );
    _activeDownloads[url] = task;

    try {
      final directory = await _getDownloadDirectory(folder, subFolder);
      final fileName = url.split('/').last;
      final savePath = '${directory.path}/$fileName';

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? received / total : 0.0;
          _activeDownloads[url] = task.copyWith(progress: progress);
          onProgress(progress);
        },
        options: Options(
          headers: {'User-Agent': 'Your User Agent'},
        ),
      );

      _activeDownloads[url] = task.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      );
    } catch (e) {
      _activeDownloads[url] = task.copyWith(status: DownloadStatus.failed);
      rethrow;
    }
  }

  Future<Directory> _getDownloadDirectory(String folder, String subFolder) async {
    Directory directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/Ragalahari Downloads/$folder/$subFolder');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/Ragalahari Downloads/$folder/$subFolder');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  List<DownloadTask> get activeDownloads => _activeDownloads.values.toList();
}

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({Key? key}) : super(key: key);

  @override
  _DownloadManagerPageState createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final Map<String, DownloadTask> _downloadTasks = {};

  @override
  void initState() {
    super.initState();
    _loadActiveDownloads();
  }

  void _loadActiveDownloads() {
    setState(() {
      _downloadTasks['url1'] = DownloadTask(
        url: 'url1',
        progress: 0.5,
        status: DownloadStatus.downloading,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveDownloads,
          ),
        ],
      ),
      body: _downloadTasks.isEmpty
          ? const Center(child: Text('No active downloads'))
          : ListView(
        children: _downloadTasks.values.map((task) => DownloadItem(
          task: task,
          onPause: () => _pauseDownload(task.url),
          onResume: () => _resumeDownload(task.url),
          onCancel: () => _cancelDownload(task.url),
        )).toList(),
      ),
    );
  }

  void _pauseDownload(String url) {
    setState(() {
      _downloadTasks[url] = _downloadTasks[url]!.copyWith(status: DownloadStatus.paused);
    });
  }

  void _resumeDownload(String url) {
    setState(() {
      _downloadTasks[url] = _downloadTasks[url]!.copyWith(status: DownloadStatus.downloading);
    });
  }

  void _cancelDownload(String url) {
    setState(() {
      _downloadTasks.remove(url);
    });
  }
}

class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const DownloadItem({
    Key? key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.url.split('/').last,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == DownloadStatus.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onResume,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: onPause,
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.cancel,
                  ),
                  onPressed: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}