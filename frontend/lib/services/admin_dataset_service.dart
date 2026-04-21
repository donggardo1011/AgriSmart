import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'api_client.dart';

class AdminDatasetService {
  ApiClient client(String token) =>
      ApiClient(baseUrl: AppConstants.apiBaseUrl, token: token);

  Future<List<Map<String, dynamic>>> list({
    required String token,
    String? q,
    String? label,
    String? split,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/datasets').replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        if (split != null && split.trim().isNotEmpty) 'split': split.trim(),
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('List datasets failed (${res.statusCode}): ${res.body}');
  }

  Future<Map<String, dynamic>> stats({required String token}) async {
    final res = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/admin/datasets/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Dataset stats failed (${res.statusCode}): ${res.body}');
  }

  Future<Map<String, dynamic>> upload({
    required String token,
    required String imagePath,
    required String label,
    required String split,
  }) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/datasets/upload')
        .replace(queryParameters: {'label': label, 'split': split});

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Upload failed (${res.statusCode}): ${res.body}');
  }

  Future<void> delete({required String token, required int id}) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.apiBaseUrl}/admin/datasets/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return;
    throw Exception('Delete failed (${res.statusCode}): ${res.body}');
  }
}

