import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AnthropicService implements ApiService {
  static const String _baseUrl = 'https://api.anthropic.com/v1';

  @override
  Future<List<Map<String, dynamic>>> getModels() async {
    // Anthropic doesn't have a public models endpoint in the same way OpenAI does.
    // We can return a static list or try to fetch if available.
    return [
      {'id': 'claude-3-5-sonnet-20240620', 'name': 'Claude 3.5 Sonnet'},
      {'id': 'claude-3-opus-20240229', 'name': 'Claude 3 Opus'},
      {'id': 'claude-3-sonnet-20240229', 'name': 'Claude 3 Sonnet'},
      {'id': 'claude-3-haiku-20240307', 'name': 'Claude 3 Haiku'},
    ];
  }

  @override
  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    String? modelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('anthropic_key') ?? '';

    if (apiKey.isEmpty) {
      throw Exception('API key not found. Please add your Anthropic key.');
    }

    final headers = {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    };

    final messages = [
      ...history,
      {'role': 'user', 'content': message},
    ];

    final body = jsonEncode({
      'model': modelId ?? 'claude-3-5-sonnet-20240620',
      'messages': messages,
      'max_tokens': 1024,
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Failed to communicate with AI: $errorMessage');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }
}
