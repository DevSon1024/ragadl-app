import 'package:flutter/material.dart';
import '../pages/ragalahari_downloader.dart';

class RagalahariDownloaderScreen extends StatelessWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const RagalahariDownloaderScreen({
    Key? key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(galleryTitle ?? 'Ragalahari Downloader'),
      ),
      body: RagalahariDownloader(
        initialUrl: initialUrl,
        initialFolder: initialFolder,
        galleryTitle: galleryTitle,
      ),
    );
  }
}