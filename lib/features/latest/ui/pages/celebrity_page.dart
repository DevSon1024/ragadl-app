import 'package:flutter/material.dart';
import 'latest_page.dart';

class LatestCelebrityPage extends StatelessWidget {
  const LatestCelebrityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LatestPage(
      title: 'Latest Celebrities',
      endpointUrl: 'https://www.ragalahari.com/starzone.aspx',
      sectionTitle: 'All Updates',
    );
  }
}
