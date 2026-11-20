// lib/screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _privacyPolicyUrl = 'https://example.com/privacy-policy';
  static const String _email = 'sanjaynewar007@gmail.com';

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': 'LiveScore Privacy Inquiry'},
    );
    if (!await launchUrl(emailUri)) {
      debugPrint('Could not launch email');
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F1623),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              size: 18,
              color: Color(0xFF0F1623),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF16A34A).withOpacity(0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.done_all_outlined,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 4),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header Card with Quiz Gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF16A34A), // Quiz section primary green
                    Color(0xFF0F7A3D), // Quiz section dark green
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.privacy_tip_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your Privacy Matters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transparency about data collection and user rights.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.update_rounded,
                        label: 'Updated: Aug 2026',
                      ),
                      _buildInfoChip(
                        icon: Icons.verified_user_rounded,
                        label: 'GDPR Compliant',
                      ),
                      _buildInfoChip(
                        icon: Icons.lock_outline_rounded,
                        label: 'Secure Storage',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Stats Cards
            Row(
              children: [
                _buildStatCard(
                  icon: Icons.storage_rounded,
                  label: 'Data Stored',
                  value: 'Local Only',
                  color: const Color(0xFF16A34A),
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.cloud_off_rounded,
                  label: 'Server Uploads',
                  value: 'None',
                  color: const Color(0xFF1A62C8),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Policy Sections
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    icon: Icons.person_outline_rounded,
                    title: '1. Information We Collect',
                    content: '''
LiveScore does not collect any personally identifiable information (PII). All user preferences, favorite teams, and profile details remain strictly on your local device storage.

We do not track location, contacts, or personal background activity.''',
                  ),
                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 32,
                    thickness: 1,
                  ),
                  _Section(
                    icon: Icons.analytics_outlined,
                    title: '2. Usage & Performance Data',
                    content: '''
Anonymous app performance metrics may be processed locally to ensure fast loading times and smooth UI rendering. No diagnostic logs contain sensitive personal information.''',
                  ),
                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 32,
                    thickness: 1,
                  ),
                  _Section(
                    icon: Icons.share_outlined,
                    title: '3. Data Sharing & Third Parties',
                    content: '''
We do not sell, rent, or trade any personal information to third parties. Public football APIs are queried directly for score updates and team information.''',
                  ),
                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 32,
                    thickness: 1,
                  ),
                  _Section(
                    icon: Icons.mail_outline_rounded,
                    title: '4. Questions & Support',
                    content: '''
If you have any questions regarding this Privacy Policy or your data, feel free to contact us directly:''',
                    customChild: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildContactTile(
                          icon: Icons.email_outlined,
                          label: 'Email Support',
                          value: _email,
                          onTap: _launchEmail,
                        ),
                        const SizedBox(height: 10),
                        _buildContactTile(
                          icon: Icons.open_in_new_rounded,
                          label: 'Full Web Policy',
                          value: _privacyPolicyUrl,
                          onTap: () => _launchUrl(_privacyPolicyUrl),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Footer Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LiveScore',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F1623),
                        ),
                      ),
                      Text(
                        '© 2026 All Rights Reserved',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Privacy Secured',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F1623),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
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

  Widget _buildContactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F1623),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Widget? customChild;

  const _Section({
    required this.icon,
    required this.title,
    required this.content,
    this.customChild,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF16A34A).withOpacity(0.15),
                    const Color(0xFF0F7A3D).withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1623),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.7,
            letterSpacing: 0.2,
          ),
        ),
        if (customChild != null) customChild!,
      ],
    );
  }
}