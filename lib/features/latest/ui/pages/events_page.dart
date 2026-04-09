import 'package:flutter/material.dart';
import 'latest_page.dart';

class LatestEventsPage extends StatelessWidget {
  const LatestEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LatestPage(
      title: 'Latest Functions',
      endpointUrl: 'https://www.ragalahari.com/functions.aspx',
      sectionTitle: 'All Events',
      actionLabel: 'Related Events',
      showActionButton: false,
    );
  }
}
