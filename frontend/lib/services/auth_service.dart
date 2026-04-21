import 'dart:convert';
import '../core/constants.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client = ApiClient(baseUrl: AppConstants.apiBaseUrl);

  Future<String> login(String username, String password) async {
    final res = await _client.post('/auth/login', {
      'username': username,
      'password': password,
      'recaptcha_token': 'dev-token',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token']?.toString();
      if (token == null) throw Exception('Missing access token');
      return token;
    }

    throw Exception('Login failed (${res.statusCode}): ${res.body}');
  }

  Future<void> register(String username, String email, String password, {String? location}) async {
    final res = await _client.post('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'location': location,
      'recaptcha_token': 'dev-token',
    });

    if (res.statusCode == 200 || res.statusCode == 201) return;

    throw Exception('Registration failed (${res.statusCode}): ${res.body}');
  }

  Future<void> forgotPassword(String email) async {
    final res = await _client.post('/auth/forgot-password', {
      'email': email,
      'recaptcha_token': 'dev-token',
    });

    if (res.statusCode == 200) return;

    throw Exception('Forgot password failed (${res.statusCode}): ${res.body}');
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl, token: accessToken);
    final res = await client.get('/auth/me');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Me failed (${res.statusCode}): ${res.body}');
  }
}
