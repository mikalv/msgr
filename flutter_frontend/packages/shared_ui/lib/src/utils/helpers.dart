import 'package:flutter/material.dart';
import 'package:messngr/utils/extensions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch URL
Future<void> launchURL(BuildContext context, String url) async {
  try {
    await launchUrl(
      Uri.parse(url).withScheme,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error! Could not launch URL')),
    );
  }
}
