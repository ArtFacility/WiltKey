import 'dart:io';
import 'dart:async';

class PairingService {
  static Future<int?> pingRelay(String relayUrl) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final stopwatch = Stopwatch()..start();
      // Normalize URL (strip trailing slashes, add ping suffix if needed)
      var cleanUrl = relayUrl.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final request = await client.getUrl(Uri.parse('$cleanUrl/ping'));
      final response = await request.close();
      stopwatch.stop();
      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (e) {
      print('Relay ping failed: $e');
    } finally {
      client.close();
    }
    return null;
  }
}
