import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';

  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/models'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawModels = data['data'] ?? [];
        return rawModels.map((m) => m as Map<String, dynamic>).toList();
      } else {
        throw Exception(
          'Failed to load models. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching models: $e');
    }
  }

  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    String modelId = 'openrouter/free',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openrouter_key') ?? '';

    if (apiKey.isEmpty) {
      throw Exception('API key not found. Please add your OpenRouter key.');
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'https://raiven.app', // Required by OpenRouter
      'X-Title': 'Raiven AI Chat', // Required by OpenRouter
      'Content-Type': 'application/json',
    };

    final messages = [
      ...history,
      {'role': 'user', 'content': message},
    ];

    final body = jsonEncode({'model': modelId, 'messages': messages});

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else if (response.statusCode == 401) {
        throw Exception(
          'Invalid OpenRouter API Key. Please check your settings and ensure it is correct.',
        );
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
