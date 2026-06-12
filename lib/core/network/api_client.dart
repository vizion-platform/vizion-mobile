import 'dart:convert';
import 'package:http/http.dart' as http;

class VizionAPIClient {
  final String _baseURL = 'https://vizion.cognisgroup.cloud/api';
  final http.Client _client = http.Client();
  String? _accessToken;
  String? _refreshToken;
  int? _tenantId;

  // Singleton
  static final VizionAPIClient instance = VizionAPIClient._internal();
  VizionAPIClient._internal();

  void setTokens(String? accessToken, String? refreshToken, int? tenantId) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tenantId = tenantId;
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty) 'Authorization': 'Bearer $_accessToken',
      if (_tenantId != null) 'X-Tenant-Id': '$_tenantId',
    };
  }

  Future<http.Response> _handleResponse(http.Response response, Future<http.Response> Function() retry) async {
    print('Response Body: ${response.body}');
    if (response.statusCode == 401) {
      if (await _refreshTokenAction()) {
        return await retry();
      }
    }
    if (response.statusCode >= 400) {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
    return response;
  }

  Future<bool> _refreshTokenAction() async {
    if (_refreshToken == null) return false;
    try {
      final response = await _client.post(
        Uri.parse('$_baseURL/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        return true;
      }
    } catch (e) {
      print('Refresh token error: $e');
    }
    return false;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final url = '$_baseURL$endpoint';
    final headers = _getHeaders();
    print('POST Request: $url');
    print('Headers: $headers');
    print('Body: $body');

    final action = () => _client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    try {
      final response = await action();
      print('Response Status: ${response.statusCode}');
      return _handleResponse(response, action);
    } catch (e) {
      print('POST Exception: $e');
      rethrow;
    }
  }

  Future<http.Response> get(String endpoint) async {
    final url = '$_baseURL$endpoint';
    final headers = _getHeaders();
    print('GET Request: $url');
    print('Headers: $headers');

    final action = () => _client.get(
      Uri.parse(url),
      headers: headers,
    );

    try {
      final response = await action();
      print('Response Status: ${response.statusCode}');
      return _handleResponse(response, action);
    } catch (e) {
      print('GET Exception: $e');
      rethrow;
    }
  }
}
