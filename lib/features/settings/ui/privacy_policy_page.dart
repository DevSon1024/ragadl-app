import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
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
                    Icons.privacy_tip_rounded,
                    size: 48,
                    color: color.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Privacy Matters',
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
                    icon: Icons.info_outline_rounded,
                    title: '1. Information We Collect',
                    content: _buildInfoCollectionContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.storage_rounded,
                    title: '2. How We Use Your Information',
                    content: _buildDataUsageContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.share_rounded,
                    title: '3. Data Sharing & Third Parties',
                    content: _buildDataSharingContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.security_rounded,
                    title: '4. Permissions & Security',
                    content: _buildPermissionsContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.account_circle_rounded,
                    title: '5. Your Rights & Controls',
                    content: _buildUserRightsContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.update_rounded,
                    title: '6. Policy Updates',
                    content: _buildPolicyUpdatesContent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    icon: Icons.child_care_rounded,
                    title: '7. Children\'s Privacy',
                    content: _buildChildrenPrivacyContent(context),
                  ),
                  const SizedBox(height: 24),
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
                Icon(Icons.verified_user_rounded, color: color.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Our Commitment',
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
              'Ragalahari Downloader ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use our image downloading application for Android devices.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: color.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We do NOT collect, store, or transmit any personal data to external servers.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
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

  Widget _buildInfoCollectionContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(
          'No Personal Data Collection',
          'We do NOT collect any personally identifiable information such as name, email, phone number, or payment details.',
        ),
        _buildBulletPoint(
          'No Account Required',
          'The app does not require user registration or account creation.',
        ),
        _buildBulletPoint(
          'Local Storage Only',
          'Download preferences and settings are stored locally on your device using SharedPreferences.',
        ),
        _buildBulletPoint(
          'Network Usage',
          'The app accesses internet only to fetch images from publicly available sources (Ragalahari.com) that you explicitly choose to download.',
        ),
        _buildBulletPoint(
          'No Analytics',
          'We do not use any analytics services to track your app usage or behavior.',
        ),
      ],
    );
  }

  Widget _buildDataUsageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All data handling occurs entirely on your device:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint(
          'Download Management',
          'URLs and download progress are temporarily stored in device memory to manage ongoing downloads.',
        ),
        _buildBulletPoint(
          'User Preferences',
          'Settings like download path, concurrent downloads limit, and folder structure preferences are saved locally.',
        ),
        _buildBulletPoint(
          'Link History',
          'Previously entered gallery links are stored locally for your convenience and can be cleared at any time.',
        ),
        _buildBulletPoint(
          'Downloaded Files',
          'Images are saved to your device storage in the location you specify. We do not upload or transmit these files anywhere.',
        ),
      ],
    );
  }

  Widget _buildDataSharingContent(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'We do NOT share any data with third parties.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildBulletPoint(
          'No Third-Party Services',
          'The app does not integrate with any third-party analytics, advertising, or data collection services.',
        ),
        _buildBulletPoint(
          'No Data Transmission',
          'No information from your device is sent to our servers or any external servers.',
        ),
        _buildBulletPoint(
          'Source Website Access',
          'The app only communicates with Ragalahari.com to fetch publicly available images when you initiate a download.',
        ),
      ],
    );
  }

  Widget _buildPermissionsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Permissions and Their Purpose:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildPermissionItem(
          Icons.wifi_rounded,
          'Internet Access',
          'Required to download images from Ragalahari.com. No data is sent from your device.',
        ),
        _buildPermissionItem(
          Icons.folder_rounded,
          'Storage Access',
          'Required to save downloaded images to your device storage and read your preferred download location.',
        ),
        _buildPermissionItem(
          Icons.notifications_rounded,
          'Notifications',
          'Used to show download progress and completion notifications. Can be disabled in device settings.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All permissions are used solely for app functionality and not for data collection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserRightsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Since we don\'t collect any personal data, you have complete control:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint(
          'Complete Control',
          'All data is stored locally on your device. You can delete it anytime by clearing app data or uninstalling the app.',
        ),
        _buildBulletPoint(
          'Clear History',
          'Use the in-app option to clear your link history and download records.',
        ),
        _buildBulletPoint(
          'Delete Downloads',
          'You can delete downloaded images directly from your device storage using any file manager.',
        ),
        _buildBulletPoint(
          'Revoke Permissions',
          'You can revoke storage or notification permissions anytime from your device settings.',
        ),
        _buildBulletPoint(
          'Uninstall Anytime',
          'Uninstalling the app removes all locally stored preferences and data.',
        ),
      ],
    );
  }

  Widget _buildPolicyUpdatesContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(
          'Notification of Changes',
          'We may update this Privacy Policy from time to time. Changes will be posted within the app and on the Play Store listing.',
        ),
        _buildBulletPoint(
          'Material Changes',
          'If we make any material changes affecting data collection, we will provide prominent notice within the app.',
        ),
        _buildBulletPoint(
          'Continued Use',
          'Your continued use of the app after policy updates constitutes acceptance of the changes.',
        ),
      ],
    );
  }

  Widget _buildChildrenPrivacyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This app is not specifically directed at children under 13. Since we do not collect any personal information, there is no risk of inadvertently collecting data from children.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'If you are a parent or guardian and believe your child has used this app, you may simply delete the app and any downloaded content from the device.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      String? url,
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
              url != null
                  ? RichText(
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.primary,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                ),
              )
                  : Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}