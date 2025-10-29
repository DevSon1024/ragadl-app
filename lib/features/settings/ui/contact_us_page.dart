import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact Us',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color.surface,
        surfaceTintColor: color.surfaceTint,
        elevation: 2,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: color.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.primaryContainer,
                    color.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.contact_mail_rounded,
                    size: 48,
                    color: color.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Updated: October 9, 2025',
                    style: TextStyle(
                      fontSize: 14,
                      color: color.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Content Sections
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIntroSection(context),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context,
                    icon: Icons.telegram,
                    title: 'Telegram Channel',
                    content: _buildTelegramContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.code,
                    title: 'GitHub Profile & Repository',
                    content: _buildGitHubContent(context),
                  ),
                  const SizedBox(height: 24),
                  _buildContactSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSection(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: color.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Row(
        children: [
        Icon(Icons.support_agent_rounded, color: color.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          'We \'re Here to Help',
        style: TextStyle(
        fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color.onSurface,
        ),
      ),
      ],
    ),
    const SizedBox(height: 12),
    Text(
    'Reach out via Telegram for updates and support, GitHub for development contributions, or email for direct inquiries.',
    style: TextStyle(
    fontSize: 14,
    height: 1.6,
    color: color.onSurface.withOpacity(0.8),
    ),
    ),
    ],
    ),
    ),
    );
    }

  Widget _buildSectionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget content,
      }) {
    final color = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelegramContent(BuildContext context) {
    return InkWell(
      onTap: () => _launchUrl('https://t.me/raga_downloader'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.telegram,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RagaDL Channel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Join for updates and support',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGitHubContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLinkItem(
          context,
          Icons.person,
          'Developer Profile',
          'DevSon1024',
          'https://github.com/DevSon1024',
        ),
        const SizedBox(height: 12),
        _buildLinkItem(
          context,
          Icons.folder,
          'Repository',
          'ragalahari_downloader_2025',
          'https://github.com/DevSon1024/ragalahari_downloader_2025',
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      color: color.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email_rounded, color: color.primary),
                const SizedBox(width: 12),
                Text(
                  'Direct Contact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'For questions or suggestions:',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: color.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              context,
              Icons.email_rounded,
              'Email',
              'dpsonawane789@gmail.com',
              'mailto:dpsonawane789@gmail.com',
            ),
            const SizedBox(height: 16),
            Text(
              'Response within 48 hours.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: color.onPrimaryContainer.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkItem(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      String url,
      ) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      String url,
      ) {
    final color = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: color.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.onPrimaryContainer.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _launchUrl(url),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}