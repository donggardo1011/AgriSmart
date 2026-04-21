// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

class ApiClient {
  final String baseUrl;
  final String? token;

  ApiClient({required this.baseUrl, this.token});

  // Increased from 15s to 30s for mobile networks (slower connections)
  static const Duration _timeout = Duration(seconds: 30);

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> get(String path) {
    return http
        .get(_uri(path), headers: _headers(json: false))
        .timeout(_timeout);
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) {
    return http
        .post(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Future<http.Response> delete(String path) {
    return http
        .delete(_uri(path), headers: _headers(json: false))
        .timeout(_timeout);
  }

  Future<http.StreamedResponse> multipartPost(
    String path, {
    required String fileField,
    required String filePath,
    String? filename,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final name = filename ?? p.basename(filePath);

    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    final parts = mimeType.split('/'); // like ["image","jpeg"]

    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
        filename: name,
        contentType: MediaType(parts[0], parts[1]),
      ),
    );

    // Add additional form fields if provided
    if (fields != null) {
      request.fields.addAll(fields);
    }

    return request.send().timeout(_timeout);
  }
}
