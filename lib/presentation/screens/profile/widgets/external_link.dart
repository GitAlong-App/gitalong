import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// [raw] as an `http(s)` URI with a host, or null for anything else (other
/// schemes such as `javascript:` are never opened).
Uri? safeWebUri(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}

/// Opens [raw] in the browser; says so in a SnackBar when it can't.
Future<void> openExternalLink(BuildContext context, String? raw) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = safeWebUri(raw);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text("Couldn't open that link. Please try again."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
