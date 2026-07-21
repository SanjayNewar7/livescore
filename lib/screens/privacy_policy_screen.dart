// lib/screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF1A62C8),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A62C8), Color(0xFF0D3F85)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: July 2026',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content
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
                  _Section(
                    title: 'Information We Collect',
                    content: '''
LiveScore collects minimal information to provide you with the best experience:

• Device information (model, OS version) for app optimization
• App usage data to improve features and performance
• Your favorite teams and players (stored locally on your device)
• Quiz scores and achievements (stored locally on your device)

We do not collect any personally identifiable information such as your name, email address, or location without your explicit consent.''',
                  ),
                  SizedBox(height: 20),
                  _Section(
                    title: 'How We Use Your Information',
                    content: '''
The information we collect is used to:

• Provide and maintain the LiveScore app
• Personalize your experience with favorites and preferences
• Improve app performance and fix bugs
• Send you notifications about your favorite teams (if enabled)
• Track quiz progress and achievements''',
                  ),
                  SizedBox(height: 20),
                  _Section(
                    title: 'Data Storage',
                    content: '''
All your preferences, favorites, and quiz data are stored locally on your device. We do not store this data on our servers.

When you clear the app cache, your preferences and favorites remain intact as they are stored in a separate secure location on your device.''',
                  ),
                  SizedBox(height: 20),
                  _Section(
                    title: 'Third-Party Services',
                    content: '''
LiveScore uses the following third-party services:

• ESPN API - for live scores, team data, and player information
• Cloudinary - for image hosting and delivery
• Google Play Services - for app distribution and updates

These services may collect data as per their respective privacy policies. We recommend reviewing their policies for more information.''',
                  ),
                  SizedBox(height: 20),
                  _Section(
                    title: 'Your Rights',
                    content: '''
You have the right to:

• Access the data stored on your device
• Delete your app data at any time
• Opt-out of notifications and alerts
• Clear all cached data from the app settings

To exercise these rights, simply go to Settings > Data & Storage in the app.''',
                  ),
                  SizedBox(height: 20),
                  _Section(
                    title: 'Contact Us',
                    content: '''
If you have any questions about this Privacy Policy, please contact us at:

Email: sanjaynewar007@gmail.com

Developer: Sanjaya Rajbhandari''',
                  ),
                  SizedBox(height: 20),
                  _Section(
                    title: 'Changes to This Policy',
                    content: '''
We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "last updated" date.

You are advised to review this Privacy Policy periodically for any changes. Changes to this Privacy Policy are effective when they are posted on this page.''',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Footer
            Center(
              child: Text(
                'LiveScore © 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;

  const _Section({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF1A62C8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1623),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}