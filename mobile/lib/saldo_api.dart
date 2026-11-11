import 'dart:convert';
import 'dart:io';

class SaldoApi {
  static const apiOverride = String.fromEnvironment('API_URL');
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  String get api => apiOverride.isNotEmpty
      ? apiOverride
      : Platform.isAndroid
      ? 'http://10.0.2.2:18080'
      : 'http://127.0.0.1:18080';

  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, [
    List<int>? body,
    ContentType? contentType,
  ]) async {
    final request = await _client.openUrl(method, Uri.parse('$api$path'));
    if (body != null) {
      request.headers.contentType = contentType ?? ContentType('text', 'csv');
      request.add(body);
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: ${text.trim()}');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  void close() => _client.close(force: true);
}
