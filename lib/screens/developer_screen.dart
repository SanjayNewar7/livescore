// lib/screens/developer_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  static const String _githubUrl = 'https://github.com/SanjayNewar7';
  static const String _linkedInUrl = 'https://www.linkedin.com/in/sanjayarajbhandari/';
  static const String _websiteUrl = 'https://sanjayarajbhandari.com.np';
  static const String _email = 'sanjaynewar007@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Developer',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16A34A), Color(0xFF0F7A3D)],
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
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sanjaya Rajbhandari',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Flutter Developer • Nepal',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Building apps that make a difference',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // About Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 3,
                        height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF16A34A),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(2),
                              bottomLeft: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'About the Developer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F1623),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Sanjaya Rajbhandari is a passionate Flutter developer from Nepal with a strong focus on creating beautiful, user-friendly mobile applications. With expertise in both Android and iOS development, Sanjaya builds apps that solve real problems and deliver exceptional user experiences.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7A96),
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This LiveScore app is a testament to his dedication to football and technology, combining real-time sports data with an intuitive interface for fans worldwide.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7A96),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Connect Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 3,
                        height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF16A34A),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(2),
                              bottomLeft: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Connect with Me',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F1623),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSocialTile(
                    icon: Icons.public,
                    title: 'Website',
                    subtitle: 'sanjayar.com.np',
                    color: const Color(0xFF16A34A),
                    onTap: () => _launchUrl(_websiteUrl),
                  ),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  _buildSocialTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: _email,
                    color: const Color(0xFF16A34A),
                    onTap: _launchEmail,
                  ),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  _buildSocialTile(
                    icon: Icons.code_rounded,
                    title: 'GitHub',
                    subtitle: 'github.com/sanjayar',
                    color: const Color(0xFF16A34A),
                    onTap: () => _launchUrl(_githubUrl),
                  ),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  _buildSocialTile(
                    icon: Icons.work_outline,
                    title: 'LinkedIn',
                    subtitle: 'linkedin.com/in/sanjaya-rajbhandari',
                    color: const Color(0xFF16A34A),
                    onTap: () => _launchUrl(_linkedInUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Footer
            Center(
              child: Text(
                'Football, The Beautiful Game',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F1623),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF6B7A96),
      ),
      onTap: onTap,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Handle error silently
      }
    } catch (_) {
      // Handle error silently
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=${Uri.encodeComponent('LiveScore App Inquiry')}',
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        // Handle error silently
      }
    } catch (_) {
      // Handle error silently
    }
  }
}