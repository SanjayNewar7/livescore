// lib/screens/developer_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  static const String _githubUrl = 'https://github.com/SanjayNewar7';
  static const String _linkedInUrl = 'https://www.linkedin.com/in/sanjayarajbhandari/';
  static const String _websiteUrl = 'https://sanjayarajbhandari.com.np';
  static const String _email = 'sanjaynewar007@gmail.com';

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': 'LiveScore App Feedback'},
    );
    if (!await launchUrl(emailUri)) {
      debugPrint('Could not launch email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Developer',
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
                  Icons.code_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 4),
                Text(
                  'Creator',
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
                          Icons.person_2_sharp,
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
                              'LiveScore',
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
                    'Sanjaya Rajbhandari',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Flutter Developer • Nepal',
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
                        icon: Icons.stars_rounded,
                        label: 'Mobile Apps',
                      ),
                      _buildInfoChip(
                        icon: Icons.terminal_rounded,
                        label: 'Flutter & Dart',
                      ),
                      _buildInfoChip(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Sports Tech',
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
                  icon: Icons.phone_android_rounded,
                  label: 'Framework',
                  value: 'Flutter',
                  color: const Color(0xFF16A34A),
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.public_rounded,
                  label: 'Location',
                  value: 'Nepal',
                  color: const Color(0xFF1A62C8),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Content Sections
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
                    icon: Icons.badge_outlined,
                    title: 'About the Developer',
                    content: '''
Sanjaya Rajbhandari is a passionate Flutter developer from Nepal with a strong focus on creating beautiful, user-friendly mobile applications. With expertise in cross-platform development, Sanjaya builds apps that solve real problems and deliver exceptional user experiences.

This LiveScore app is a testament to his dedication to football and technology, combining real-time sports data with an intuitive interface for fans worldwide.''',
                  ),
                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 32,
                    thickness: 1,
                  ),
                  _Section(
                    icon: Icons.hub_outlined,
                    title: 'Connect & Follow',
                    content: 'Feel free to reach out via email or explore social profiles and web links below:',
                    customChild: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildSocialLinkTile(
                          icon: Icons.code_rounded,
                          label: 'GitHub',
                          value: 'github.com/SanjayNewar7',
                          onTap: () => _launchUrl(_githubUrl),
                        ),
                        const SizedBox(height: 10),
                        _buildSocialLinkTile(
                          icon: Icons.work_outline_rounded,
                          label: 'LinkedIn',
                          value: 'in/sanjayarajbhandari',
                          onTap: () => _launchUrl(_linkedInUrl),
                        ),
                        const SizedBox(height: 10),
                        _buildSocialLinkTile(
                          icon: Icons.language_rounded,
                          label: 'Portfolio',
                          value: 'sanjayarajbhandari.com.np',
                          onTap: () => _launchUrl(_websiteUrl),
                        ),
                        const SizedBox(height: 10),
                        _buildSocialLinkTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _email,
                          onTap: _launchEmail,
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
                        Icons.favorite_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Made in Nepal',
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

  Widget _buildSocialLinkTile({
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
              Icons.open_in_new_rounded,
              size: 16,
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