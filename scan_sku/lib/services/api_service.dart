import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'jwt_token';
  static const String _urlKey = 'server_url';
  static String get _defaultUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://192.168.31.183:3000/api';

  // Base URL Methods
  static Future<void> saveBaseUrl(String url) async {
    if (url.trim().isEmpty) {
      await _storage.delete(key: _urlKey);
      return;
    }
    // Clean up trailing slash if any
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _storage.write(key: _urlKey, value: cleanUrl);
  }

  static Future<String> getBaseUrl() async {
    final url = await _storage.read(key: _urlKey);
    return url ?? _defaultUrl;
  }

  // Auth Methods
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final baseUrl = await getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['data']['token'];
      if (token != null) {
        await saveToken(token);
      }
      return data;
    } else {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Failed to login');
    }
  }

  // SKU Methods
  static Future<Map<String, dynamic>> checkSkuDuplicate(String skuCode) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/scan-sku/check?skuCode=$skuCode'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to check SKU');
    }
  }

  static Future<Map<String, dynamic>> fetchSkus({
    String search = '',
    int limit = 10,
    int page = 1,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/scan-sku?search=$search&limit=$limit&page=$page'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load SKUs');
    }
  }

  static Future<Map<String, dynamic>> submitSku({
    required String skuCode,
    required String color,
    required int quantity,
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/scan-sku'),
      headers: headers,
      body: json.encode({
        'skuCode': skuCode,
        'color': color,
        'quantity': quantity,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Failed to submit SKU');
    }
  }
}
