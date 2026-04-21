import 'dart:convert';
import '../core/constants.dart';
import 'api_client.dart';

class ChatbotService {
  final String? token;

  ChatbotService({this.token});

  ApiClient get _client =>
      ApiClient(baseUrl: AppConstants.apiBaseUrl, token: token);

  Future<String?> ask(String disease, String message) async {
    final res = await _client.post('/api/chatbot', {
      'disease': disease,
      'message': message,
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['reply']?.toString();
    }

    throw Exception('Chatbot failed (${res.statusCode}): ${res.body}');
  }
}
