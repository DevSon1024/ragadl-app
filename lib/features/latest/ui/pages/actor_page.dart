import 'package:flutter/material.dart';
import 'latest_page.dart';

class ActorPage extends StatelessWidget {
  const ActorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LatestPage(
      title: 'Latest Actors',
      endpointUrl: 'https://www.ragalahari.com/actor/starzone.aspx',
      sectionTitle: 'All Updates',
    );
  }
}
