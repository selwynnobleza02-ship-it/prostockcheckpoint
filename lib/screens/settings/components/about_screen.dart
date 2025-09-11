import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('1.0.0+1'), // Hardcoded for now
          ),
          const Divider(),
          ListTile(
            title: const Text('Help & Support'),
            onTap: () => _launchURL('https://your-support-page.com'),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () => _launchURL('https://your-privacy-policy.com'),
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: () => _launchURL('https://your-terms-of-service.com'),
          ),
        ],
      ),
    );
  }
}
