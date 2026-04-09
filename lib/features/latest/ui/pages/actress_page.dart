import 'package:flutter/material.dart';
import 'latest_page.dart';

class ActressPage extends StatelessWidget {
  const ActressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LatestPage(
      title: 'Latest Actresses',
      endpointUrl: 'https://www.ragalahari.com/actress/starzone.aspx',
      sectionTitle: 'All Updates',
    );
  }
}
