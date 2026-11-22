import 'package:url_launcher/url_launcher.dart';

/// Opens a link in an external app; injectable so tests need no platform.
abstract class UrlOpener {
  /// Returns true only when the URL was handed to an external app.
  Future<bool> open(String url);
}

class DefaultUrlOpener implements UrlOpener {
  const DefaultUrlOpener();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
