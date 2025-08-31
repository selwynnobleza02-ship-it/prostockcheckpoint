import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
            onTap: () {
              // TODO: Implement link to help and support page
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              // TODO: Implement link to privacy policy page
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            onTap: () {
              // TODO: Implement link to terms of service page
            },
          ),
        ],
      ),
    );
  }
}
