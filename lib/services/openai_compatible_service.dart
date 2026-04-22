import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OpenAiCompatibleService implements ApiService {
  final String baseUrl;
  final String apiKeyKey;
  final String defaultModel;

  OpenAiCompatibleService({
    required this.baseUrl,
    required this.apiKeyKey,
    this.defaultModel = 'gpt-3.5-turbo',
  });

  @override
  Future<List<Map<String, dynamic>>> getModels() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(apiKeyKey) ?? '';

    if (apiKey.isEmpty) {
      throw Exception('API key not found. Please add your key in settings.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

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

  @override
  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    String? modelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(apiKeyKey) ?? '';

    if (apiKey.isEmpty) {
      throw Exception('API key not found. Please add your key in settings.');
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final messages = [
      ...history,
      {'role': 'user', 'content': message},
    ];

    final body = jsonEncode({
      'model': modelId ?? defaultModel,
      'messages': messages,
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
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
