import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class AdminInsightsService {
  String get _base => AppConstants.apiBaseUrl;

  Future<Map<String, dynamic>> userCount({required String token}) async {
    final res = await http.get(
      Uri.parse('$_base/admin/users/count'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('User count failed (${res.statusCode}): ${res.body}');
  }

  Future<List<Map<String, dynamic>>> listUsers({
    required String token,
    String? q,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_base/admin/users').replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('List users failed (${res.statusCode}): ${res.body}');
  }

  Future<List<Map<String, dynamic>>> listActivities({
    required String token,
    int? userId,
    String? action,
    int limit = 100,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_base/admin/activities').replace(
      queryParameters: {
        if (userId != null) 'user_id': '$userId',
        if (action != null && action.trim().isNotEmpty) 'action': action.trim(),
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('List activities failed (${res.statusCode}): ${res.body}');
  }
}

